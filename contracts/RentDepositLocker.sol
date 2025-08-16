// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RentDepositLocker {
    enum Status { Active, Disputed, Finalized }

    struct Lease {
        address landlord;
        address tenant;
        address resolver;
        uint256 deposit;
        uint64 start;
        uint64 end;
        Status status;
        bytes32 releaseHash;
        bool tenantApproved;
        bool landlordApproved;
        bool refunded;
    }

    uint256 public nextLeaseId;
    mapping(uint256 => Lease) public leases;
    mapping(uint256 => mapping(address => uint256)) public credits;

    event LeaseCreated(uint256 indexed leaseId, address indexed landlord, address indexed tenant, uint256 deposit, uint64 end, address resolver);
    event DisputeRaised(uint256 indexed leaseId);
    event MutualReleaseProposed(uint256 indexed leaseId, uint256 landlordShare, uint256 tenantShare, bytes32 releaseHash);
    event MutualReleaseApproved(uint256 indexed leaseId, address indexed by);
    event Resolved(uint256 indexed leaseId, uint256 landlordShare, uint256 tenantShare, address indexed by);
    event Refunded(uint256 indexed leaseId, uint256 amount, address indexed to);
    event Withdrawn(uint256 indexed leaseId, address indexed to, uint256 amount);

    bool private locked;
    modifier nonReentrant() { require(!locked, "reentrancy"); locked = true; _; locked = false; }

    modifier onlyLandlord(uint256 leaseId) { require(msg.sender == leases[leaseId].landlord, "not landlord"); _; }
    modifier onlyTenant(uint256 leaseId) { require(msg.sender == leases[leaseId].tenant, "not tenant"); _; }
    modifier onlyResolver(uint256 leaseId) { require(msg.sender == leases[leaseId].resolver, "not resolver"); _; }
    modifier exists(uint256 leaseId) { require(leases[leaseId].landlord != address(0), "lease?"); _; }
    modifier active(uint256 leaseId) { require(leases[leaseId].status == Status.Active, "not active"); _; }

    function createLease(address tenant, uint64 end, address resolver) external payable returns (uint256 leaseId) {
        require(tenant != address(0) && tenant != msg.sender, "bad tenant");
        require(end > block.timestamp, "bad end");
        require(msg.value > 0, "deposit=0");
        leaseId = ++nextLeaseId;
        leases[leaseId] = Lease({
            landlord: msg.sender,
            tenant: tenant,
            resolver: resolver,
            deposit: msg.value,
            start: uint64(block.timestamp),
            end: end,
            status: Status.Active,
            releaseHash: bytes32(0),
            tenantApproved: false,
            landlordApproved: false,
            refunded: false
        });
        emit LeaseCreated(leaseId, msg.sender, tenant, msg.value, end, resolver);
    }

    function raiseDispute(uint256 leaseId) external exists(leaseId) active(leaseId) onlyLandlord(leaseId) {
        leases[leaseId].status = Status.Disputed;
        emit DisputeRaised(leaseId);
    }

    function claimRefund(uint256 leaseId) external exists(leaseId) onlyTenant(leaseId) active(leaseId) {
        Lease storage L = leases[leaseId];
        require(block.timestamp >= L.end, "not ended");
        require(!L.refunded, "done");
        L.status = Status.Finalized;
        L.refunded = true;
        credits[leaseId][L.tenant] += L.deposit;
        emit Refunded(leaseId, L.deposit, L.tenant);
    }

    function proposeMutualRelease(uint256 leaseId, uint256 landlordShare, uint256 tenantShare) external exists(leaseId) {
        Lease storage L = leases[leaseId];
        require(L.status != Status.Finalized, "finalized");
        require(landlordShare + tenantShare == L.deposit, "sum!=deposit");
        bytes32 h = keccak256(abi.encode(landlordShare, tenantShare));
        if (L.releaseHash == bytes32(0)) {
            L.releaseHash = h;
            L.tenantApproved = false;
            L.landlordApproved = false;
            emit MutualReleaseProposed(leaseId, landlordShare, tenantShare, h);
        } else {
            require(L.releaseHash == h, "mismatch");
        }
        if (msg.sender == L.tenant) {
            L.tenantApproved = true;
            emit MutualReleaseApproved(leaseId, msg.sender);
        } else if (msg.sender == L.landlord) {
            L.landlordApproved = true;
            emit MutualReleaseApproved(leaseId, msg.sender);
        } else {
            revert("not party");
        }
        if (L.tenantApproved && L.landlordApproved) {
            L.status = Status.Finalized;
            L.refunded = true;
            (uint256 ls, uint256 ts) = _decodeRelease(L.releaseHash);
            credits[leaseId][L.landlord] += ls;
            credits[leaseId][L.tenant] += ts;
            emit Resolved(leaseId, ls, ts, address(0));
        }
    }

    function resolveByResolver(uint256 leaseId, uint256 landlordShare, uint256 tenantShare) external exists(leaseId) onlyResolver(leaseId) {
        Lease storage L = leases[leaseId];
        require(L.status != Status.Finalized, "finalized");
        require(landlordShare + tenantShare == L.deposit, "sum!=deposit");
        L.status = Status.Finalized;
        L.refunded = true;
        credits[leaseId][L.landlord] += landlordShare;
        credits[leaseId][L.tenant] += tenantShare;
        emit Resolved(leaseId, landlordShare, tenantShare, msg.sender);
    }

    function withdraw(uint256 leaseId) external nonReentrant exists(leaseId) {
        uint256 amt = credits[leaseId][msg.sender];
        require(amt > 0, "no funds");
        credits[leaseId][msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amt}("");
        require(ok, "xfer");
        emit Withdrawn(leaseId, msg.sender, amt);
    }

    function getLease(uint256 leaseId) external view returns (
        address landlord, address tenant, address resolver, uint256 deposit, uint64 start, uint64 end, Status status,
        bytes32 releaseHash, bool tenantApproved, bool landlordApproved, bool refunded
    ) {
        Lease memory L = leases[leaseId];
        landlord = L.landlord; tenant = L.tenant; resolver = L.resolver; deposit = L.deposit;
        start = L.start; end = L.end; status = L.status; releaseHash = L.releaseHash;
        tenantApproved = L.tenantApproved; landlordApproved = L.landlordApproved; refunded = L.refunded;
    }

    function _decodeRelease(bytes32 h) private pure returns (uint256 landlordShare, uint256 tenantShare) {
        bytes memory b = abi.encodePacked(h);
        landlordShare = uint256(bytes32(b));
        tenantShare = 0; // not used directly; stored via hash check only
    }
}

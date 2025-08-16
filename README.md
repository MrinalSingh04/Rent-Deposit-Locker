# ⏳ Rent Deposit Locker

## 💡 What

A **smart contract** that securely holds a tenant’s **rent deposit** on-chain during the lease period.

- 🏠 **Tenant** locks deposit → safe & transparent  
- 📅 Deposit stays locked until the lease ends 
- 🔓 **Auto-refund** to tenant if no dispute arises 
- ⚖️ If there’s a **dispute**, funds are released only after:
  - ✅ Mutual agreement (both landlord & tenant approve same split) 
  - 👨‍⚖️ Resolver/arbitrator decides distribution 

---

## 🤔 Why

Traditional rental deposits rely on **trust** between landlord & tenant — which often causes disputes.  
This contract removes uncertainty by enforcing **rules on-chain**:

- 🔒 **Security** → Funds cannot be misused or withheld unfairly
- 🌐 **Transparency** → Both parties can see deposit status anytime
- ⚡ **Automation** → Refunds & releases follow code, not human bias
- 🕊️ **Fair Disputes** → Either mutual release or neutral resolver
- 🚪 **Trustless Exit** → Tenant can claim refund automatically once the lease ends if no dispute exists

---

## ✨ Key Features

- 📜 Lease creation with locked deposit
- ⏳ Time-based auto-refund if no dispute
- 🧾 Mutual release mechanism requiring both parties to agree
- 👨‍⚖️ Resolver/arbitrator support for conflict resolution
- 💰 Pull-based withdrawals → safe against reentrancy

---

## 🔄 Lifecycle

1. **Create Lease** 🏗️

   - Landlord creates lease & locks deposit
   - Event emitted: `LeaseCreated`

2. **Active Lease** 📅

   - Deposit stays locked until lease end
   - If landlord suspects damage → raises `Dispute`

3. **Settlement** 🤝

   - ✅ No dispute → Tenant claims refund
   - ✍️ Mutual release → Both approve split
   - 👨‍⚖️ Resolver → Decides final distribution

4. **Withdraw** 💳
   - Parties withdraw credited funds to wallets

---

## 🚀 Benefits

- 🏡 Fair for both **landlord** & **tenant**
- 🔍 Verifiable by **anyone on-chain**
- 🛡️ Protects against **fraud or unfair withholding**
- 🌱 Can be extended to cover **monthly rent, evidence, or DAO-based arbitration**

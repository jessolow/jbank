# J Bank Backend - Simple Architecture

A modern, modular banking backend built on Supabase with a clean, simple architecture.

## 🏗️ **Architecture Overview**

### **Design Principles**
- **Simple & Clean**: Minimal, focused services with clear responsibilities
- **Double-Entry Accounting**: Proper ledger system with balanced transactions
- **Idempotency**: All operations are safe to retry
- **JWT Authentication**: Secure user authentication via Supabase Auth
- **Modular Services**: Clear separation between vertical and horizontal services

### **Service Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    SUPABASE AUTH                            │
│                   (Identity Source)                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                HORIZONTAL SERVICES                          │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │  Customer       │  │  Core Ledger    │  │ Transaction │ │
│  │  Master         │  │  (Authoritative)│  │  History    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                VERTICAL SERVICES                            │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │  Deposit Core   │  │  Lending Core   │                  │
│  │  (Accounts)     │  │  (LoC + Loans)  │                  │
│  └─────────────────┘  └─────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **Implementation Status**

### ✅ **COMPLETED**

#### **1. Customer Master (Auth + Profile)**
- **Database**: `public.customer_profile` table with 3 fields
- **RPC**: `get_or_create_profile()` function
- **Edge Function**: `profile/index.ts` - Returns `{ user_id, full_name }`
- **Status**: ✅ **FULLY IMPLEMENTED & DEPLOYED**

#### **2. Core Ledger Schema**
- **Tables**: `ledger_transactions`, `ledger_accounts`, `ledger_entries`
- **View**: `account_balances` for account balances
- **Function**: `post_balanced_transaction()` for double-entry validation
- **Status**: ✅ **FULLY IMPLEMENTED & DEPLOYED**

#### **3. Core Ledger Edge Functions**
- **`ledgerPostings`**: Posts balanced transactions with JSON lines
- **`ledgerTransferInternal`**: Internal transfers between accounts
- **Status**: ✅ **FULLY IMPLEMENTED & DEPLOYED**

#### **4. Deposit Core Schema**
- **Table**: `deposit_core.deposit_accounts` with auto-ledger creation
- **Trigger**: Auto-creates ledger accounts on deposit account creation
- **Status**: ✅ **FULLY IMPLEMENTED & DEPLOYED**

#### **5. Deposit Core Edge Functions**
- **`depositsCreate`**: Creates deposit accounts, returns both IDs
- **Status**: ✅ **FULLY IMPLEMENTED & DEPLOYED**

#### **6. Lending Core LoC Schema**
- **Table**: `lending_core.loc_accounts` for Line of Credit accounts
- **View**: `lending_core.loc_exposure` for credit exposure calculations
- **Status**: ✅ **FULLY IMPLEMENTED & DEPLOYED**

#### **7. Lending Core Create LoC**
- **Edge Function**: `lendingCreateLoc` - Creates LoC with unique account numbers
- **Status**: ✅ **FULLY IMPLEMENTED & DEPLOYED**

### 🚧 **IN PROGRESS**

#### **8. Lending Core Loan Schema**
- **Tables**: `term_loans`, `repayment_schedule`
- **Loan ledger accounts**: 6 accounts per loan (principal + interest × 3 states)
- **Status**: 🔄 **NEXT TO IMPLEMENT**

#### **9. Lending Core Create Loan**
- **Edge Function**: Complex loan creation with schedule generation
- **Status**: 🔄 **PENDING LOAN SCHEMA**

#### **10. Scheduled Functions**
- **Interest accrual**: Daily at 01:00
- **Due date processing**: Daily at 00:10
- **Overdue aging**: Daily at 00:30
- **Status**: 🔄 **PENDING LOAN SCHEMA**

#### **11. Transaction History**
- **Table**: `history.events` for audit trail
- **View**: `history.timeline_by_customer` for unified timeline
- **Edge Function**: `historyGet` for paginated history
- **Status**: 🔄 **PENDING IMPLEMENTATION**

#### **12. RLS & Policies**
- **Row Level Security**: Enable on all tables
- **Policies**: User ownership and bank-level restrictions
- **Status**: 🔄 **PENDING IMPLEMENTATION**

#### **13. Guardrails & Validation**
- **Shared module**: `_shared/validation.ts`
- **SQL invariants**: Database-level checks
- **Status**: 🔄 **PENDING IMPLEMENTATION**

#### **14. Loan Repayment**
- **Edge Function**: `loansRepay` for payment processing
- **Status**: 🔄 **PENDING LOAN SCHEMA**

#### **15. Admin Tooling**
- **Edge Function**: `adminAccountLookup` for debugging
- **Status**: 🔄 **PENDING IMPLEMENTATION**

## 🗄️ **Database Schema**

### **Core Tables**

#### **Customer Profile**
```sql
public.customer_profile (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id),
    full_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
)
```

#### **Core Ledger**
```sql
ledger_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    idempotency_key TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    meta JSONB DEFAULT '{}'::jsonb
)

ledger_accounts (
    id BIGSERIAL PRIMARY KEY,
    owner_type TEXT CHECK (owner_type IN ('CUSTOMER','LOAN','BANK')),
    owner_id TEXT NOT NULL,
    code TEXT NOT NULL,
    currency TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(owner_type, owner_id, code, currency)
)

ledger_entries (
    id BIGSERIAL PRIMARY KEY,
    txn_id BIGINT REFERENCES ledger_transactions(id) ON DELETE CASCADE,
    account_id BIGINT REFERENCES ledger_accounts(id) ON DELETE RESTRICT,
    amount_cents BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
)
```

#### **Deposit Core**
```sql
deposit_core.deposit_accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    currency TEXT NOT NULL,
    status TEXT DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW()
)
```

#### **Lending Core**
```sql
lending_core.loc_accounts (
    loc_account_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    account_number TEXT UNIQUE NOT NULL,
    currency TEXT NOT NULL,
    credit_limit_cents BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
)
```

## 🔌 **API Endpoints**

### **Customer Master**
- `GET /functions/v1/profile` - Get or create user profile

### **Core Ledger**
- `POST /functions/v1/ledgerPostings` - Post balanced transactions
- `POST /functions/v1/ledgerTransferInternal` - Internal transfers

### **Deposit Core**
- `POST /functions/v1/depositsCreate` - Create deposit account

### **Lending Core**
- `POST /functions/v1/lendingCreateLoc` - Create Line of Credit

## 🛠️ **Technology Stack**

- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **Language**: TypeScript (Deno runtime)
- **Database**: PostgreSQL with advanced features
- **Authentication**: Supabase Auth (JWT)
- **API**: RESTful Edge Functions
- **Deployment**: Supabase Cloud

## 🚀 **Quick Start**

### **Prerequisites**
- Node.js 18+
- Supabase CLI
- Supabase project

### **Setup**
```bash
# Clone and setup
git clone <repository>
cd backend

# Install dependencies
npm install

# Link to Supabase project
supabase link --project-ref <your-project-ref>

# Apply migrations
supabase db push

# Deploy functions
supabase functions deploy --use-api
```

### **Environment Variables**
```bash
# Copy template
cp env.template .env

# Fill in your values
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

## 📊 **Key Features**

### **Double-Entry Accounting**
- All transactions must balance (sum to zero)
- Proper debit/credit handling
- Account balance calculations

### **Idempotency**
- Safe to retry operations
- Unique idempotency keys
- Prevents duplicate transactions

### **Security**
- JWT authentication required
- Row-level security (when enabled)
- Service role for admin operations

### **Performance**
- Optimized indexes
- Efficient queries
- Connection pooling

## 🔒 **Security Features**

- **Authentication**: JWT tokens via Supabase Auth
- **Authorization**: User-scoped data access
- **Validation**: Input sanitization and validation
- **Audit Trail**: Transaction logging and history

## 🧪 **Testing**

### **Manual Testing**
```bash
# Test profile function
curl -X GET https://your-project.supabase.co/functions/v1/profile \
  -H "Authorization: Bearer <jwt-token>"

# Test deposit creation
curl -X POST https://your-project.supabase.co/functions/v1/depositsCreate \
  -H "Authorization: Bearer <jwt-token>" \
  -H "Content-Type: application/json" \
  -d '{"currency": "USD"}'
```

## 📈 **Monitoring & Logging**

- **Function Logs**: Available in Supabase Dashboard
- **Database Logs**: PostgreSQL logging
- **Performance**: Query performance monitoring
- **Errors**: Structured error responses

## 🚀 **Deployment**

### **Production**
```bash
# Deploy all functions
supabase functions deploy --use-api

# Apply migrations
supabase db push
```

### **Local Development**
```bash
# Start local Supabase
supabase start

# Apply local migrations
supabase db reset
```

## 📚 **API Documentation**

### **Request Headers**
- `Authorization: Bearer <jwt-token>` - Required for all endpoints
- `Content-Type: application/json` - For POST requests
- `x-idempotency-key: <unique-key>` - For idempotent operations

### **Response Format**
```json
{
  "success": true,
  "data": { ... },
  "error": null
}
```

### **Error Format**
```json
{
  "success": false,
  "data": null,
  "error": "Error message",
  "details": "Additional error details"
}
```

## 🔄 **Migration History**

- **0001_init.sql** - Initial setup (users, OTP, sessions)
- **0002_core_ledger.sql** - Core ledger system
- **0003_deposit_core.sql** - Deposit accounts
- **0004_simple_customer_profile.sql** - Customer profiles
- **0004_lending_core_loc.sql** - Line of Credit accounts

## 🤝 **Contributing**

1. Follow the simple architecture principles
2. Implement one service at a time
3. Include proper validation and error handling
4. Add comprehensive tests
5. Update documentation

## 📞 **Support**

- **Issues**: Create GitHub issues
- **Documentation**: Check this README
- **Supabase**: Official Supabase documentation

## 📄 **License**

This project is proprietary to J Bank.

---

**Last Updated**: August 2024  
**Version**: 2.0 (Simple Architecture)  
**Status**: Core Services Complete, Expanding Features

-- Lending Core Loan Schema - Term loans with repayment schedules
-- Migration: 0005_lending_core_loan.sql
-- Creates term loans and auto-creates related ledger accounts

-- Create term_loans table
CREATE TABLE IF NOT EXISTS lending_core.term_loans (
    loan_id BIGSERIAL PRIMARY KEY,
    loc_account_id BIGINT NOT NULL REFERENCES lending_core.loc_accounts(loc_account_id),
    user_id UUID NOT NULL,
    loan_account_number TEXT UNIQUE NOT NULL,
    principal_amount_cents BIGINT NOT NULL,
    monthly_interest_rate_bps INTEGER NOT NULL, -- Basis points (1/100th of 1%)
    tenure_months INTEGER NOT NULL,
    start_date DATE NOT NULL,
    maturity_date DATE NOT NULL,
    status TEXT DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create repayment_schedule table
CREATE TABLE IF NOT EXISTS lending_core.repayment_schedule (
    schedule_id BIGSERIAL PRIMARY KEY,
    loan_id BIGINT NOT NULL REFERENCES lending_core.term_loans(loan_id) ON DELETE CASCADE,
    due_date DATE NOT NULL,
    principal_due_cents BIGINT NOT NULL,
    interest_due_cents BIGINT NOT NULL,
    status TEXT DEFAULT 'PENDING',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_term_loans_loc_account_id ON lending_core.term_loans(loc_account_id);
CREATE INDEX IF NOT EXISTS idx_term_loans_user_id ON lending_core.term_loans(user_id);
CREATE INDEX IF NOT EXISTS idx_term_loans_loan_account_number ON lending_core.term_loans(loan_account_number);
CREATE INDEX IF NOT EXISTS idx_term_loans_status ON lending_core.term_loans(status);
CREATE INDEX IF NOT EXISTS idx_repayment_schedule_loan_id ON lending_core.repayment_schedule(loan_id);
CREATE INDEX IF NOT EXISTS idx_repayment_schedule_due_date ON lending_core.repayment_schedule(due_date);
CREATE INDEX IF NOT EXISTS idx_repayment_schedule_status ON lending_core.repayment_schedule(status);

-- Function to create loan ledger accounts for new term loans
CREATE OR REPLACE FUNCTION lending_core.create_loan_ledger_accounts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Insert six loan ledger accounts for codes:
    -- CUSTOMER_PRINCIPAL_CHARGED, CUSTOMER_PRINCIPAL_DUE, CUSTOMER_PRINCIPAL_OVERDUE
    -- CUSTOMER_INTEREST_CHARGED, CUSTOMER_INTEREST_DUE, CUSTOMER_INTEREST_OVERDUE
    
    INSERT INTO ledger_accounts (owner_type, owner_id, code, currency) VALUES
        ('LOAN', NEW.loan_id::text, 'CUSTOMER_PRINCIPAL_CHARGED', 'USD'),
        ('LOAN', NEW.loan_id::text, 'CUSTOMER_PRINCIPAL_DUE', 'USD'),
        ('LOAN', NEW.loan_id::text, 'CUSTOMER_PRINCIPAL_OVERDUE', 'USD'),
        ('LOAN', NEW.loan_id::text, 'CUSTOMER_INTEREST_CHARGED', 'USD'),
        ('LOAN', NEW.loan_id::text, 'CUSTOMER_INTEREST_DUE', 'USD'),
        ('LOAN', NEW.loan_id::text, 'CUSTOMER_INTEREST_OVERDUE', 'USD');
    
    -- Also ensure bank-level ledger account exists for BANK_INTEREST_EARNED
    INSERT INTO ledger_accounts (owner_type, owner_id, code, currency)
    VALUES ('BANK', 'BANK:INTEREST', 'BANK_INTEREST_EARNED', 'USD')
    ON CONFLICT (owner_type, owner_id, code, currency) DO NOTHING;
    
    -- Link the loan to the LoC in the mapping table
    INSERT INTO lending_core.loan_loc_mapping (loc_account_id, loan_id)
    VALUES (NEW.loc_account_id, NEW.loan_id);
    
    RETURN NEW;
END;
$$;

-- Create trigger to auto-create loan ledger accounts on term loan creation
DROP TRIGGER IF EXISTS trigger_create_loan_ledger_accounts ON lending_core.term_loans;
CREATE TRIGGER trigger_create_loan_ledger_accounts
    AFTER INSERT ON lending_core.term_loans
    FOR EACH ROW
    EXECUTE FUNCTION lending_core.create_loan_ledger_accounts();

-- Simple alias view mapping OVERUDE → OVERDUE to tolerate the typo
CREATE OR REPLACE VIEW lending_core.loan_ledger_accounts AS
SELECT 
    id,
    owner_type,
    owner_id,
    CASE 
        WHEN code = 'CUSTOMER_PRINCIPAL_OVERUDE' THEN 'CUSTOMER_PRINCIPAL_OVERDUE'
        WHEN code = 'CUSTOMER_INTEREST_OVERUDE' THEN 'CUSTOMER_INTEREST_OVERDUE'
        ELSE code
    END as code,
    currency,
    created_at
FROM ledger_accounts
WHERE owner_type = 'LOAN' AND code LIKE 'CUSTOMER_%';

-- Grant permissions
GRANT SELECT, INSERT ON lending_core.term_loans TO authenticated;
GRANT SELECT, INSERT ON lending_core.repayment_schedule TO authenticated;
GRANT SELECT ON lending_core.loan_ledger_accounts TO authenticated;
GRANT USAGE ON SCHEMA lending_core TO authenticated;

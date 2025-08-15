-- Lending Core Line of Credit Schema
-- Migration: 0004_lending_core_loc.sql
-- Creates LoC accounts and exposure calculation view

-- Create lending_core schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS lending_core;

-- Create the loc_accounts table
CREATE TABLE IF NOT EXISTS lending_core.loc_accounts (
    loc_account_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    account_number TEXT UNIQUE NOT NULL,
    currency TEXT NOT NULL,
    credit_limit_cents BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_loc_accounts_user_id ON lending_core.loc_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_loc_accounts_account_number ON lending_core.loc_accounts(account_number);

-- Create a helper table to relate loans to LoC (for the exposure view)
CREATE TABLE IF NOT EXISTS lending_core.loan_loc_mapping (
    id BIGSERIAL PRIMARY KEY,
    loc_account_id BIGINT NOT NULL REFERENCES lending_core.loc_accounts(loc_account_id) ON DELETE CASCADE,
    loan_id BIGINT NOT NULL, -- Will reference term_loans table when created
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(loan_id)
);

-- Create the loc_exposure view that computes per LoC
CREATE OR REPLACE VIEW lending_core.loc_exposure AS
SELECT 
    loc.loc_account_id,
    loc.user_id,
    loc.account_number,
    loc.currency,
    loc.credit_limit_cents,
    
    -- Principal components (sum of balances for loan-related ledger accounts)
    COALESCE(SUM(CASE 
        WHEN la.code IN ('CUSTOMER_PRINCIPAL_CHARGED', 'CUSTOMER_PRINCIPAL_DUE', 'CUSTOMER_PRINCIPAL_OVERDUE')
        THEN COALESCE(ab.balance_cents, 0)
        ELSE 0
    END), 0) as principal_components_cents,
    
    -- Available credit
    loc.credit_limit_cents - COALESCE(SUM(CASE 
        WHEN la.code IN ('CUSTOMER_PRINCIPAL_CHARGED', 'CUSTOMER_PRINCIPAL_DUE', 'CUSTOMER_PRINCIPAL_OVERDUE')
        THEN COALESCE(ab.balance_cents, 0)
        ELSE 0
    END), 0) as available_credit_cents,
    
    -- Outstanding amount (sum of all six loan components)
    COALESCE(SUM(CASE 
        WHEN la.code IN (
            'CUSTOMER_PRINCIPAL_CHARGED', 'CUSTOMER_PRINCIPAL_DUE', 'CUSTOMER_PRINCIPAL_OVERDUE',
            'CUSTOMER_INTEREST_CHARGED', 'CUSTOMER_INTEREST_DUE', 'CUSTOMER_INTEREST_OVERDUE'
        )
        THEN COALESCE(ab.balance_cents, 0)
        ELSE 0
    END), 0) as outstanding_amount_cents

FROM lending_core.loc_accounts loc
LEFT JOIN lending_core.loan_loc_mapping llm ON loc.loc_account_id = llm.loc_account_id
LEFT JOIN ledger_accounts la ON la.owner_type = 'LOAN' AND la.owner_id = llm.loan_id::text
LEFT JOIN account_balances ab ON la.id = ab.account_id
GROUP BY loc.loc_account_id, loc.user_id, loc.account_number, loc.currency, loc.credit_limit_cents;

-- Grant permissions
GRANT SELECT, INSERT ON lending_core.loc_accounts TO authenticated;
GRANT SELECT, INSERT ON lending_core.loan_loc_mapping TO authenticated;
GRANT SELECT ON lending_core.loc_exposure TO authenticated;
GRANT USAGE ON SCHEMA lending_core TO authenticated;

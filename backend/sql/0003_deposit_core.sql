-- Deposit Core Schema - Simple structure with auto-ledger creation
-- Migration: 0003_deposit_core.sql
-- Creates deposit accounts and auto-creates related ledger accounts

-- Create deposit_core schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS deposit_core;

-- Create the simple deposit_accounts table
CREATE TABLE IF NOT EXISTS deposit_core.deposit_accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    currency TEXT NOT NULL,
    status TEXT DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_deposit_accounts_user_id ON deposit_core.deposit_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_deposit_accounts_status ON deposit_core.deposit_accounts(status);

-- Function to create ledger account for new deposit account
CREATE OR REPLACE FUNCTION deposit_core.create_ledger_account()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Insert a ledger_accounts row for this deposit account
    INSERT INTO ledger_accounts (
        owner_type,
        owner_id,
        code,
        currency
    ) VALUES (
        'CUSTOMER',
        NEW.user_id::text || ':' || NEW.id::text,
        'CUSTOMER_DEPOSIT_ACCOUNT',
        NEW.currency
    );
    
    RETURN NEW;
END;
$$;

-- Create trigger to auto-create ledger account on deposit account creation
DROP TRIGGER IF EXISTS trigger_create_ledger_account ON deposit_core.deposit_accounts;
CREATE TRIGGER trigger_create_ledger_account
    AFTER INSERT ON deposit_core.deposit_accounts
    FOR EACH ROW
    EXECUTE FUNCTION deposit_core.create_ledger_account();

-- Grant permissions
GRANT SELECT, INSERT ON deposit_core.deposit_accounts TO authenticated;
GRANT USAGE ON SCHEMA deposit_core TO authenticated;

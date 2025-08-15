-- Core Ledger Schema - Simple 3-table structure
-- Migration: 0002_core_ledger.sql
-- Implements the authoritative ledger system for double-entry accounting

-- ============================================================================
-- CORE LEDGER TABLES
-- ============================================================================

-- Main transactions table
CREATE TABLE IF NOT EXISTS ledger_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    idempotency_key TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    meta JSONB DEFAULT '{}'::jsonb
);

-- Ledger accounts for all entities
CREATE TABLE IF NOT EXISTS ledger_accounts (
    id BIGSERIAL PRIMARY KEY,
    owner_type TEXT NOT NULL CHECK (owner_type IN ('CUSTOMER', 'LOAN', 'BANK')),
    owner_id TEXT NOT NULL,
    code TEXT NOT NULL,
    currency TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint on (owner_type, owner_id, code, currency)
    UNIQUE(owner_type, owner_id, code, currency)
);

-- Individual ledger entries (debits/credits)
CREATE TABLE IF NOT EXISTS ledger_entries (
    id BIGSERIAL PRIMARY KEY,
    txn_id BIGINT NOT NULL REFERENCES ledger_transactions(id) ON DELETE CASCADE,
    account_id BIGINT NOT NULL REFERENCES ledger_accounts(id) ON DELETE RESTRICT,
    amount_cents BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_ledger_transactions_user_id ON ledger_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_ledger_transactions_idempotency ON ledger_transactions(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_ledger_accounts_owner ON ledger_accounts(owner_type, owner_id);
CREATE INDEX IF NOT EXISTS idx_ledger_accounts_code ON ledger_accounts(code);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_txn_id ON ledger_entries(txn_id);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_account_id ON ledger_entries(account_id);

-- ============================================================================
-- ACCOUNT BALANCES VIEW
-- ============================================================================

CREATE OR REPLACE VIEW account_balances AS
SELECT 
    account_id,
    SUM(amount_cents) as balance_cents
FROM ledger_entries
GROUP BY account_id;

-- ============================================================================
-- CORE FUNCTION: POST BALANCED TRANSACTION
-- ============================================================================

CREATE OR REPLACE FUNCTION post_balanced_transaction(
    p_user UUID,
    p_idem TEXT,
    p_lines JSONB,
    p_meta JSONB DEFAULT '{}'::jsonb
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    txn_id BIGINT;
    line_record RECORD;
    total_amount BIGINT := 0;
BEGIN
    -- Check if transaction already exists (idempotency)
    SELECT id INTO txn_id 
    FROM ledger_transactions 
    WHERE idempotency_key = p_idem;
    
    IF FOUND THEN
        RETURN txn_id; -- Return existing transaction ID
    END IF;
    
    -- Validate that lines sum to zero (double-entry requirement)
    FOR line_record IN SELECT * FROM jsonb_array_elements(p_lines)
    LOOP
        total_amount := total_amount + (line_record->>'amount_cents')::BIGINT;
    END LOOP;
    
    IF total_amount != 0 THEN
        RAISE EXCEPTION 'Transaction lines must sum to zero, got: %', total_amount;
    END IF;
    
    -- Create the transaction
    INSERT INTO ledger_transactions (user_id, idempotency_key, meta)
    VALUES (p_user, p_idem, p_meta)
    RETURNING id INTO txn_id;
    
    -- Insert all ledger entries
    FOR line_record IN SELECT * FROM jsonb_array_elements(p_lines)
    LOOP
        INSERT INTO ledger_entries (txn_id, account_id, amount_cents)
        VALUES (
            txn_id,
            (line_record->>'account_id')::BIGINT,
            (line_record->>'amount_cents')::BIGINT
        );
    END LOOP;
    
    RETURN txn_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION post_balanced_transaction(UUID, TEXT, JSONB, JSONB) TO authenticated;

-- Grant permissions on tables
GRANT SELECT, INSERT ON ledger_transactions TO authenticated;
GRANT SELECT, INSERT ON ledger_accounts TO authenticated;
GRANT SELECT, INSERT ON ledger_entries TO authenticated;
GRANT SELECT ON account_balances TO authenticated;

-- Transaction History Schema - Read model for unified timeline
-- Migration: 0006_transaction_history.sql
-- Creates events table and timeline view for customer transaction history

-- Create history schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS history;

-- Create the events table for audit trail
CREATE TABLE IF NOT EXISTS history.events (
    event_id BIGSERIAL PRIMARY KEY,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type TEXT NOT NULL,
    actor TEXT NOT NULL,
    ref JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_events_occurred_at ON history.events(occurred_at);
CREATE INDEX IF NOT EXISTS idx_events_event_type ON history.events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_actor ON history.events(actor);

-- Create the timeline_by_customer view that joins multiple sources
CREATE OR REPLACE VIEW history.timeline_by_customer AS
SELECT 
    customer_id,
    date,
    type,
    amounts,
    refs
FROM (
    -- Ledger transactions timeline
    SELECT 
        lt.user_id as customer_id,
        lt.created_at::date as date,
        'ledger_transaction' as type,
        jsonb_build_object(
            'debits', COALESCE(SUM(CASE WHEN le.amount_cents > 0 THEN le.amount_cents ELSE 0 END), 0),
            'credits', COALESCE(SUM(CASE WHEN le.amount_cents < 0 THEN ABS(le.amount_cents) ELSE 0 END), 0),
            'net', COALESCE(SUM(le.amount_cents), 0)
        ) as amounts,
        jsonb_build_object(
            'txn_id', lt.id,
            'idempotency_key', lt.idempotency_key,
            'meta', lt.meta
        ) as refs
    FROM ledger_transactions lt
    LEFT JOIN ledger_entries le ON lt.id = le.txn_id
    GROUP BY lt.id, lt.user_id, lt.created_at, lt.idempotency_key, lt.meta
    
    UNION ALL
    
    -- Deposit accounts timeline
    SELECT 
        da.user_id as customer_id,
        da.created_at::date as date,
        'deposit_account_created' as type,
        jsonb_build_object(
            'currency', da.currency
        ) as amounts,
        jsonb_build_object(
            'deposit_account_id', da.id,
            'status', da.status
        ) as refs
    FROM deposit_core.deposit_accounts da
    
    UNION ALL
    
    -- Account balance changes (from ledger entries)
    SELECT 
        lt.user_id as customer_id,
        le.created_at::date as date,
        'balance_change' as type,
        jsonb_build_object(
            'amount_cents', le.amount_cents,
            'account_id', le.account_id
        ) as amounts,
        jsonb_build_object(
            'txn_id', le.txn_id,
            'account_code', la.code,
            'owner_type', la.owner_type,
            'owner_id', la.owner_id
        ) as refs
    FROM ledger_entries le
    JOIN ledger_transactions lt ON le.txn_id = lt.id
    JOIN ledger_accounts la ON le.account_id = la.id
    WHERE la.owner_type = 'CUSTOMER'
) timeline_data
ORDER BY customer_id, date DESC, type;

-- Create a function to add events to the history
CREATE OR REPLACE FUNCTION history.add_event(
    p_event_type TEXT,
    p_actor TEXT,
    p_ref JSONB DEFAULT '{}'::jsonb
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    event_id BIGINT;
BEGIN
    INSERT INTO history.events (event_type, actor, ref)
    VALUES (p_event_type, p_actor, p_ref)
    RETURNING event_id INTO event_id;
    
    RETURN event_id;
END;
$$;

-- Grant permissions
GRANT SELECT ON history.events TO authenticated;
GRANT SELECT ON history.timeline_by_customer TO authenticated;
GRANT EXECUTE ON FUNCTION history.add_event(TEXT, TEXT, JSONB) TO authenticated;
GRANT USAGE ON SCHEMA history TO authenticated;

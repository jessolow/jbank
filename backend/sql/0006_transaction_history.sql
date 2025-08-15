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
    references
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
        ) as references
    FROM ledger_transactions lt
    LEFT JOIN ledger_entries le ON lt.id = le.txn_id
    GROUP BY lt.id, lt.user_id, lt.created_at, lt.idempotency_key, lt.meta
    
    UNION ALL
    
    -- Term loans timeline
    SELECT 
        tl.user_id as customer_id,
        tl.created_at::date as date,
        'loan_created' as type,
        jsonb_build_object(
            'principal_amount_cents', tl.principal_amount_cents,
            'monthly_interest_rate_bps', tl.monthly_interest_rate_bps,
            'tenure_months', tl.tenure_months
        ) as amounts,
        jsonb_build_object(
            'loan_id', tl.loan_id,
            'loan_account_number', tl.loan_account_number,
            'loc_account_id', tl.loc_account_id,
            'start_date', tl.start_date,
            'maturity_date', tl.maturity_date
        ) as references
    
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
        ) as references
    
    UNION ALL
    
    -- Line of Credit timeline
    SELECT 
        loc.user_id as customer_id,
        loc.created_at::date as date,
        'loc_created' as type,
        jsonb_build_object(
            'credit_limit_cents', loc.credit_limit_cents,
            'currency', loc.currency
        ) as amounts,
        jsonb_build_object(
            'loc_account_id', loc.loc_account_id,
            'account_number', loc.account_number
        ) as references
    
    UNION ALL
    
    -- Repayment schedule timeline (for due dates)
    SELECT 
        tl.user_id as customer_id,
        rs.due_date as date,
        'payment_due' as type,
        jsonb_build_object(
            'principal_due_cents', rs.principal_due_cents,
            'interest_due_cents', rs.interest_due_cents,
            'total_due_cents', rs.principal_due_cents + rs.interest_due_cents
        ) as amounts,
        jsonb_build_object(
            'loan_id', tl.loan_id,
            'loan_account_number', tl.loan_account_number,
            'schedule_id', rs.schedule_id,
            'status', rs.status
        ) as references
    FROM lending_core.repayment_schedule rs
    JOIN lending_core.term_loans tl ON rs.loan_id = tl.loan_id
    WHERE rs.status IN ('PENDING', 'DUE', 'OVERDUE')
    
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
        ) as references
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

-- RLS & Security Policies
-- Migration: 0007_rls_policies.sql
-- Enables Row Level Security on all tables with proper policies

-- Enable RLS on all tables
ALTER TABLE public.customer_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE deposit_core.deposit_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE lending_core.loc_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE lending_core.term_loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE lending_core.repayment_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- CUSTOMER PROFILE POLICIES
-- ============================================================================

-- Users can only view and update their own profile
CREATE POLICY "Users can view own profile" ON public.customer_profile
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile" ON public.customer_profile
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can insert their own profile (for the get_or_create_profile function)
CREATE POLICY "Users can insert own profile" ON public.customer_profile
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- DEPOSIT ACCOUNTS POLICIES
-- ============================================================================

-- Users can only view and manage their own deposit accounts
CREATE POLICY "Users can view own deposit accounts" ON deposit_core.deposit_accounts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own deposit accounts" ON deposit_core.deposit_accounts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own deposit accounts" ON deposit_core.deposit_accounts
    FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================================
-- LINE OF CREDIT POLICIES
-- ============================================================================

-- Users can only view and manage their own LoC accounts
CREATE POLICY "Users can view own LoC accounts" ON lending_core.loc_accounts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own LoC accounts" ON lending_core.loc_accounts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own LoC accounts" ON lending_core.loc_accounts
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can only view their own LoC mappings
CREATE POLICY "Users can view own LoC mappings" ON lending_core.loan_loc_mapping
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM lending_core.loc_accounts 
            WHERE loc_account_id = lending_core.loan_loc_mapping.loc_account_id 
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own LoC mappings" ON lending_core.loan_loc_mapping
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM lending_core.loc_accounts 
            WHERE loc_account_id = lending_core.loan_loc_mapping.loc_account_id 
            AND user_id = auth.uid()
        )
    );

-- ============================================================================
-- TERM LOANS POLICIES
-- ============================================================================

-- Users can only view and manage their own loans
CREATE POLICY "Users can view own loans" ON lending_core.term_loans
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own loans" ON lending_core.term_loans
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own loans" ON lending_core.term_loans
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can only view their own repayment schedules
CREATE POLICY "Users can view own repayment schedules" ON lending_core.repayment_schedule
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM lending_core.term_loans 
            WHERE loan_id = lending_core.repayment_schedule.loan_id 
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own repayment schedules" ON lending_core.repayment_schedule
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM lending_core.term_loans 
            WHERE loan_id = lending_core.repayment_schedule.loan_id 
            AND user_id = auth.uid()
        )
    );

-- ============================================================================
-- LEDGER ACCOUNTS POLICIES
-- ============================================================================

-- Users can view their own customer accounts
CREATE POLICY "Users can view own customer accounts" ON ledger_accounts
    FOR SELECT USING (
        (owner_type = 'CUSTOMER' AND owner_id LIKE auth.uid()::text || ':%') OR
        (owner_type = 'LOAN' AND EXISTS (
            SELECT 1 FROM lending_core.term_loans 
            WHERE loan_id::text = owner_id AND user_id = auth.uid()
        )) OR
        (owner_type = 'BANK' AND owner_id IN ('BANK:INTEREST')) -- Allow view of bank interest accounts
    );

-- Users can insert their own customer accounts (for deposit creation)
CREATE POLICY "Users can insert own customer accounts" ON ledger_accounts
    FOR INSERT WITH CHECK (
        (owner_type = 'CUSTOMER' AND owner_id LIKE auth.uid()::text || ':%') OR
        (owner_type = 'LOAN' AND EXISTS (
            SELECT 1 FROM lending_core.term_loans 
            WHERE loan_id::text = owner_id AND user_id = auth.uid()
        ))
    );

-- Users can update their own customer accounts
CREATE POLICY "Users can update own customer accounts" ON ledger_accounts
    FOR UPDATE USING (
        (owner_type = 'CUSTOMER' AND owner_id LIKE auth.uid()::text || ':%') OR
        (owner_type = 'LOAN' AND EXISTS (
            SELECT 1 FROM lending_core.term_loans 
            WHERE loan_id::text = owner_id AND user_id = auth.uid()
        ))
    );

-- ============================================================================
-- LEDGER TRANSACTIONS POLICIES
-- ============================================================================

-- Users can view their own transactions
CREATE POLICY "Users can view own transactions" ON ledger_transactions
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own transactions
CREATE POLICY "Users can insert own transactions" ON ledger_transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own transactions (for metadata updates)
CREATE POLICY "Users can update own transactions" ON ledger_transactions
    FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================================
-- LEDGER ENTRIES POLICIES
-- ============================================================================

-- Users can view entries for their own transactions
CREATE POLICY "Users can view own ledger entries" ON ledger_entries
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM ledger_transactions 
            WHERE id = ledger_entries.txn_id AND user_id = auth.uid()
        )
    );

-- Users can insert entries for their own transactions
CREATE POLICY "Users can insert own ledger entries" ON ledger_entries
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM ledger_transactions 
            WHERE id = ledger_entries.txn_id AND user_id = auth.uid()
        )
    );

-- Users can update entries for their own transactions
CREATE POLICY "Users can update own ledger entries" ON ledger_entries
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM ledger_transactions 
            WHERE id = ledger_entries.txn_id AND user_id = auth.uid()
        )
    );

-- ============================================================================
-- HISTORY EVENTS POLICIES
-- ============================================================================

-- Users can view their own events
CREATE POLICY "Users can view own events" ON history.events
    FOR SELECT USING (
        actor = auth.uid()::text OR
        ref->>'user_id' = auth.uid()::text
    );

-- Users can insert their own events
CREATE POLICY "Users can insert own events" ON history.events
    FOR INSERT WITH CHECK (
        actor = auth.uid()::text OR
        ref->>'user_id' = auth.uid()::text
    );

-- ============================================================================
-- VIEW POLICIES (Views don't need RLS policies - they inherit from base tables)
-- ============================================================================

-- Note: Views like account_balances, loc_exposure, and timeline_by_customer
-- inherit their security from the underlying tables and don't need separate RLS policies.
-- The RLS policies on the base tables (ledger_accounts, ledger_transactions, etc.)
-- will automatically secure the views.

-- ============================================================================
-- SERVICE ROLE BYPASS
-- ============================================================================

-- Create a function to check if the current user has service role
CREATE OR REPLACE FUNCTION public.has_service_role()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- This function will be called by service role functions
    -- to bypass RLS when needed
    RETURN current_setting('role') = 'service_role';
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.has_service_role() TO authenticated;

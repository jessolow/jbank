-- Simple Customer Profile Schema
-- Migration: 0004_simple_customer_profile.sql
-- Creates a basic customer_profile table with helper RPC

-- Create the simple customer_profile table
CREATE TABLE IF NOT EXISTS public.customer_profile (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_customer_profile_user_id ON public.customer_profile(user_id);

-- Helper RPC function: get_or_create_profile()
CREATE OR REPLACE FUNCTION get_or_create_profile()
RETURNS TABLE(user_id UUID, full_name TEXT, created_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Try to get existing profile
    RETURN QUERY
    SELECT cp.user_id, cp.full_name, cp.created_at
    FROM public.customer_profile cp
    WHERE cp.user_id = auth.uid();
    
    -- If no profile found, insert a placeholder and return it
    IF NOT FOUND THEN
        INSERT INTO public.customer_profile (user_id, full_name)
        VALUES (auth.uid(), 'New User')
        ON CONFLICT (user_id) DO NOTHING;
        
        RETURN QUERY
        SELECT cp.user_id, cp.full_name, cp.created_at
        FROM public.customer_profile cp
        WHERE cp.user_id = auth.uid();
    END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_or_create_profile() TO authenticated;

-- Grant select permission on customer_profile table
GRANT SELECT ON public.customer_profile TO authenticated;

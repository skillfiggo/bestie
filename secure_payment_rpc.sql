-- ================================================================
-- CRITICAL SECURITY FIX: underlying Database RPC
-- ================================================================

-- The function 'process_successful_payment' is 'SECURITY DEFINER', 
-- which means it runs with Admin privileges.
-- However, by default, it is executable by PUBLIC (any user).
-- This allows a malicious user to bypass payment verification 
-- and call this function directly to add coins.

-- 1. Revoke public access
REVOKE EXECUTE ON FUNCTION process_successful_payment(uuid, text, numeric, int, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION process_successful_payment(uuid, text, numeric, int, text) FROM anon;
REVOKE EXECUTE ON FUNCTION process_successful_payment(uuid, text, numeric, int, text) FROM authenticated;

-- 2. Allow ONLY Service Role (used by Edge Functions)
GRANT EXECUTE ON FUNCTION process_successful_payment(uuid, text, numeric, int, text) TO service_role;

-- Note: This ensures only your 'verify-payment' Edge Function 
-- (which uses the Service Role Key) can call this logic.

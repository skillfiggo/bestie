-- ============================================
-- SECURE PAYMENT LOGS & HISTORY
-- ============================================

-- 1. SECURE payment_log
-- This table is used for debugging and tracking payment attempts
ALTER TABLE public.payment_log ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own logs
DROP POLICY IF EXISTS "Users can view own logs" ON public.payment_log;
CREATE POLICY "Users can view own logs"
ON public.payment_log
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Admins can view all logs
DROP POLICY IF EXISTS "Admins can view all logs" ON public.payment_log;
CREATE POLICY "Admins can view all logs"
ON public.payment_log
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- 2. SECURE payment_history
-- This table tracks successful transactions and coin balances
ALTER TABLE public.payment_history ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own payment history
DROP POLICY IF EXISTS "Users can view own payment history" ON public.payment_history;
CREATE POLICY "Users can view own payment history"
ON public.payment_history
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Admins can view all payment history
DROP POLICY IF EXISTS "Admins can view all payment history" ON public.payment_history;
CREATE POLICY "Admins can view all payment history"
ON public.payment_history
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- VERIFICATION MESSAGE
-- ============================================
-- Run this in the Supabase SQL Editor. 
-- Then refresh the Security Advisor to confirm RLS is enabled.

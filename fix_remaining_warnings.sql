-- ============================================
-- SUPPLEMENTARY FIX FOR REMAINING WARNINGS
-- Run this AFTER fix_search_path_warnings.sql
-- ============================================

-- ============================================
-- 1. FIX REMAINING SEARCH PATH WARNINGS
-- ============================================

-- These functions already exist but may need to be recreated
-- Drop them first to ensure clean recreation
DROP FUNCTION IF EXISTS update_uploaded_at_column();

-- Re-create with SET search_path
CREATE OR REPLACE FUNCTION update_uploaded_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Verify the other functions have search_path
-- (They should have been fixed in the main script, but let's recreate to be sure)

DROP FUNCTION IF EXISTS process_earning_transfer(uuid, uuid, int);
CREATE OR REPLACE FUNCTION process_earning_transfer(
  p_call_id UUID,
  p_receiver_id UUID,
  p_coins_spent INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_diamonds_earned INT;
BEGIN
  v_diamonds_earned := FLOOR(p_coins_spent * 0.4);
  
  UPDATE profiles
  SET diamonds = diamonds + v_diamonds_earned
  WHERE id = p_receiver_id;
  
  INSERT INTO earnings_history (receiver_id, source_type, source_id, coins_received, diamonds_earned)
  VALUES (p_receiver_id, 'call', p_call_id, p_coins_spent, v_diamonds_earned);
END;
$$;

DROP FUNCTION IF EXISTS submit_withdrawal_request(numeric, text, text, text);
CREATE OR REPLACE FUNCTION submit_withdrawal_request(
  p_amount NUMERIC,
  p_bank_code TEXT,
  p_account_number TEXT,
  p_account_name TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_current_diamonds INT;
  v_request_id UUID;
BEGIN
  v_user_id := auth.uid();
  
  SELECT diamonds INTO v_current_diamonds
  FROM profiles
  WHERE id = v_user_id;
  
  IF v_current_diamonds < p_amount THEN
    RAISE EXCEPTION 'Insufficient diamonds';
  END IF;
  
  INSERT INTO withdrawal_requests (
    user_id, amount, bank_code, account_number, account_name
  ) VALUES (
    v_user_id, p_amount, p_bank_code, p_account_number, p_account_name
  )
  RETURNING id INTO v_request_id;
  
  RETURN v_request_id;
END;
$$;

DROP FUNCTION IF EXISTS get_nearby_profiles(double precision, double precision, double precision, text);
CREATE OR REPLACE FUNCTION get_nearby_profiles(
  lat DOUBLE PRECISION,
  long DOUBLE PRECISION,
  radius_km DOUBLE PRECISION,
  target_gender TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  avatar_url TEXT,
  age INTEGER,
  gender TEXT,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.name,
    p.avatar_url,
    p.age,
    p.gender,
    (
      6371 * acos(
        least(1.0, greatest(-1.0,
          cos(radians(lat)) * cos(radians(p.latitude)) *
          cos(radians(p.longitude) - radians(long)) +
          sin(radians(lat)) * sin(radians(p.latitude))
        ))
      )
    ) AS distance_km
  FROM
    profiles p
  WHERE
    p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    AND (target_gender IS NULL OR p.gender = target_gender)
    AND (p.gender != 'female' OR p.is_verified = true)
    AND (
      6371 * acos(
        least(1.0, greatest(-1.0,
          cos(radians(lat)) * cos(radians(p.latitude)) *
          cos(radians(p.longitude) - radians(long)) +
          sin(radians(lat)) * sin(radians(p.latitude))
        ))
      )
    ) <= radius_km
  ORDER BY
    distance_km ASC;
END;
$$;

-- ============================================
-- 2. FIX DEBUG_LOGS RLS POLICY (OVERLY PERMISSIVE)
-- ============================================

-- The current policy allows ANYONE to read/write debug logs
-- Let's restrict it to authenticated users only for production

DROP POLICY IF EXISTS "Public Read" ON public.debug_logs;
DROP POLICY IF EXISTS "Public Insert" ON public.debug_logs;

-- Option 1: Admin only (Most secure - recommended for production)
CREATE POLICY "Admin Read Debug Logs" 
  ON public.debug_logs 
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admin Insert Debug Logs" 
  ON public.debug_logs 
  FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
  );

-- Option 2: If you need system functions to write logs, keep insert permissive
-- but restrict reads to admins
-- Uncomment below if you need this:
/*
DROP POLICY IF EXISTS "Admin Insert Debug Logs" ON public.debug_logs;
CREATE POLICY "System Insert Debug Logs" 
  ON public.debug_logs 
  FOR INSERT 
  WITH CHECK (true);  -- Allow system to write, but only admins can read
*/

-- ============================================
-- 3. ENABLE LEAKED PASSWORD PROTECTION (OPTIONAL)
-- ============================================

-- This is a Supabase Auth configuration, not SQL
-- To enable it, go to:
-- Supabase Dashboard → Authentication → Settings → Security
-- Toggle ON: "Leaked Password Protection"

-- NOTE: This uses HaveIBeenPwned API to check passwords
-- It may add slight latency to signup/password changes

COMMENT ON TABLE debug_logs IS 'Debug logging table - restricted to admins only';

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '✅ Supplementary fixes applied';
  RAISE NOTICE '✅ Function search paths secured';
  RAISE NOTICE '✅ Debug logs RLS restricted to admins';
  RAISE NOTICE '⚠️  Remember to enable Leaked Password Protection in Supabase Dashboard → Auth → Settings';
END $$;

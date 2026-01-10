-- ============================================
-- DIRECT FIX FOR 4 REMAINING WARNINGS  
-- Copy and paste this ENTIRE script into Supabase SQL Editor
-- ============================================

-- Fix 1: update_updated_at_column
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

CREATE OR REPLACE FUNCTION update_updated_at_column()
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

-- Recreate trigger
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Fix 2: get_nearby_profiles  
DROP FUNCTION IF EXISTS get_nearby_profiles(double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS get_nearby_profiles(double precision, double precision, double precision, text) CASCADE;

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

-- Fix 3: process_earning_transfer
DROP FUNCTION IF EXISTS process_earning_transfer(uuid, uuid, int) CASCADE;

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

-- Fix 4: submit_withdrawal_request
DROP FUNCTION IF EXISTS submit_withdrawal_request(numeric, text, text, text) CASCADE;

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

-- Verification query - Run after the above to check
SELECT 
  proname as function_name,
  prosecdef as has_security_definer,
  proconfig as config
FROM pg_proc 
WHERE pronamespace = 'public'::regnamespace
  AND proname IN (
    'update_updated_at_column',
    'get_nearby_profiles',
    'process_earning_transfer',
    'submit_withdrawal_request'
  )
ORDER BY proname;

-- You should see config = {search_path=public} for each function
-- If you see this, the warnings are FIXED!

DO $$
BEGIN
  RAISE NOTICE '✅ All 4 functions updated with SET search_path = public';
  RAISE NOTICE '✅ Warnings should be resolved now!';
  RAISE NOTICE '🔄 Refresh your Supabase Advisors panel to verify';
END $$;

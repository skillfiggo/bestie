-- Fix Payment Coin Delivery Issues
-- This script ensures payment verification and webhook delivery work reliably

-- 1. Ensure email column exists in profiles table
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'email'
    ) THEN
        ALTER TABLE profiles ADD COLUMN email TEXT;
        CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
    END IF;
END $$;

-- 2. Backfill missing emails from auth.users
-- This is critical for webhook lookups
UPDATE profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id 
  AND (p.email IS NULL OR p.email = '');

-- 3. Enhanced payment processing function with better error handling
CREATE OR REPLACE FUNCTION process_successful_payment(
  p_user_id uuid,
  p_reference text,
  p_amount numeric,
  p_coins int,
  p_provider text
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_balance int;
  v_msg text;
BEGIN
  -- 1. Insert into payment_history
  -- If reference exists, this will fail with unique violation (prevents double-crediting)
  INSERT INTO payment_history (user_id, reference, provider, amount, coins_added)
  VALUES (p_user_id, p_reference, p_provider, p_amount, p_coins);

  -- 2. Update profile coins atomically
  UPDATE profiles
  SET coins = coins + p_coins
  WHERE id = p_user_id
  RETURNING coins INTO v_new_balance;

  -- 3. Send success notification
  v_msg := '🎉 Recharge Successful! You have received ' || p_coins || ' coins. Your new balance is ' || v_new_balance || ' coins.';
  
  -- Try to send notification, but don't fail if it errors
  BEGIN
    PERFORM send_official_message(p_user_id, v_msg);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to send official message: %', SQLERRM;
  END;

  RETURN v_new_balance;
END;
$$;

-- 4. Create a function to lookup user by email for webhook (more robust)
CREATE OR REPLACE FUNCTION get_user_id_by_email(p_email text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- First try: Direct lookup in profiles
  SELECT id INTO v_user_id
  FROM profiles
  WHERE LOWER(email) = LOWER(p_email)
  LIMIT 1;
  
  -- Second try: Lookup in auth.users if not found in profiles
  IF v_user_id IS NULL THEN
    SELECT u.id INTO v_user_id
    FROM auth.users u
    WHERE LOWER(u.email) = LOWER(p_email)
    LIMIT 1;
  END IF;
  
  RETURN v_user_id;
END;
$$;

-- 5. Grant necessary permissions
GRANT EXECUTE ON FUNCTION process_successful_payment(uuid, text, numeric, int, text) TO service_role;
GRANT EXECUTE ON FUNCTION get_user_id_by_email(text) TO service_role;

-- 6. Verify payment_history table structure
DO $$
BEGIN
  -- Ensure unique constraint exists on reference
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'payment_history_reference_key'
  ) THEN
    ALTER TABLE payment_history ADD CONSTRAINT payment_history_reference_key UNIQUE (reference);
  END IF;
END $$;

-- 7. Add logging table for payment debugging (optional but recommended)
CREATE TABLE IF NOT EXISTS payment_log (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  reference text,
  email text,
  user_id uuid,
  amount numeric,
  coins int,
  provider text,
  success boolean,
  error_message text,
  created_at timestamptz DEFAULT now()
);

-- 8. Enhanced logging function
CREATE OR REPLACE FUNCTION log_payment_attempt(
  p_reference text,
  p_email text,
  p_user_id uuid,
  p_amount numeric,
  p_coins int,
  p_provider text,
  p_success boolean,
  p_error_message text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO payment_log (reference, email, user_id, amount, coins, provider, success, error_message)
  VALUES (p_reference, p_email, p_user_id, p_amount, p_coins, p_provider, p_success, p_error_message);
END;
$$;

GRANT EXECUTE ON FUNCTION log_payment_attempt(text, text, uuid, numeric, int, text, boolean, text) TO service_role;

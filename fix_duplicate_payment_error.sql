-- Fix Duplicate Payment Reference Error
-- This script updates the payment processing function to gracefully handle
-- duplicate reference attempts (already processed payments)

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
  v_existing_coins int;
  v_existing_payment record;
  v_msg text;
BEGIN
  -- 1. Check if this reference was already processed
  SELECT user_id, coins_added INTO v_existing_payment
  FROM payment_history
  WHERE reference = p_reference
  LIMIT 1;
  
  -- If reference exists, check if it was for this same user
  IF v_existing_payment IS NOT NULL THEN
    IF v_existing_payment.user_id = p_user_id THEN
      -- Same user, same reference - already credited, return current balance
      SELECT coins INTO v_new_balance FROM profiles WHERE id = p_user_id;
      RAISE NOTICE 'Payment already processed for this user. Coins already credited.';
      RETURN v_new_balance;
    ELSE
      -- Different user trying to use same reference - security issue!
      RAISE EXCEPTION 'Payment reference already used by another account';
    END IF;
  END IF;
  
  -- 2. Insert into payment_history (will fail on duplicate if race condition)
  BEGIN
    INSERT INTO payment_history (user_id, reference, provider, amount, coins_added)
    VALUES (p_user_id, p_reference, p_provider, p_amount, p_coins);
  EXCEPTION WHEN unique_violation THEN
    -- Race condition: another request already inserted this reference
    -- Fetch and return current balance
    SELECT coins INTO v_new_balance FROM profiles WHERE id = p_user_id;
    RETURN v_new_balance;
  END;

  -- 3. Update profile coins atomically
  UPDATE profiles
  SET coins = coins + p_coins
  WHERE id = p_user_id
  RETURNING coins INTO v_new_balance;

  -- 4. Send success notification
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

-- Re-grant permissions
GRANT EXECUTE ON FUNCTION process_successful_payment(uuid, text, numeric, int, text) TO service_role;

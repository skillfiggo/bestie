-- ============================================
-- FINAL FIX FOR LAST 2 WARNINGS
-- These are the EXACT function signatures from your database
-- ============================================

-- Fix 1: process_earning_transfer with 4 parameters
DROP FUNCTION IF EXISTS process_earning_transfer(uuid, uuid, int, text) CASCADE;

CREATE OR REPLACE FUNCTION process_earning_transfer(
    p_sender_id UUID,
    p_receiver_id UUID,
    p_coin_amount INT,
    p_transaction_type TEXT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_diamond_earned INT;
    v_new_balance INT;
BEGIN
    -- 1. Deduct Coins from Sender
    UPDATE profiles 
    SET coins = coins - p_coin_amount 
    WHERE id = p_sender_id AND coins >= p_coin_amount
    RETURNING coins INTO v_new_balance;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient coins';
    END IF;

    -- 2. Calculate 40% Share for Creator
    v_diamond_earned := floor(p_coin_amount * 0.4);

    -- 3. Credit Diamonds to Creator
    UPDATE profiles 
    SET diamonds = diamonds + v_diamond_earned 
    WHERE id = p_receiver_id;

    -- 4. Record Transaction
    INSERT INTO earnings_history (
        creator_id, 
        source_user_id, 
        transaction_type, 
        coins_spent, 
        diamonds_earned
    ) VALUES (
        p_receiver_id, 
        p_sender_id, 
        p_transaction_type, 
        p_coin_amount, 
        v_diamond_earned
    );

    RETURN v_new_balance;
END;
$$;

-- Fix 2: submit_withdrawal_request with 7 parameters
DROP FUNCTION IF EXISTS submit_withdrawal_request(uuid, int, decimal, text, text, text, text) CASCADE;

CREATE OR REPLACE FUNCTION submit_withdrawal_request(
    p_user_id UUID,
    p_amount_diamonds INT,
    p_amount_naira DECIMAL,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_name TEXT,
    p_bank_code TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_request_id UUID;
BEGIN
    -- 1. Verify and deduct diamonds
    UPDATE profiles 
    SET diamonds = diamonds - p_amount_diamonds 
    WHERE id = p_user_id AND diamonds >= p_amount_diamonds;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient diamond balance';
    END IF;

    -- 2. Create the request
    INSERT INTO withdrawal_requests (
        user_id,
        amount_diamonds,
        amount_naira,
        bank_name,
        account_number,
        account_name,
        bank_code,
        status
    ) VALUES (
        p_user_id,
        p_amount_diamonds,
        p_amount_naira,
        p_bank_name,
        p_account_number,
        p_account_name,
        p_bank_code,
        'pending'
    ) RETURNING id INTO v_request_id;

    RETURN v_request_id;
END;
$$;

-- Verification
SELECT 
  proname as function_name,
  pg_get_function_arguments(oid) as parameters,
  prosecdef as security_definer,
  proconfig as config
FROM pg_proc 
WHERE pronamespace = 'public'::regnamespace
  AND proname IN (
    'process_earning_transfer',
    'submit_withdrawal_request'
  )
ORDER BY proname;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Fixed process_earning_transfer with correct 4-parameter signature';
  RAISE NOTICE '✅ Fixed submit_withdrawal_request with correct 7-parameter signature';
  RAISE NOTICE '✅ Both functions now have SET search_path = public';
  RAISE NOTICE '🔄 Refresh Supabase Advisors panel - warnings should be GONE!';
END $$;

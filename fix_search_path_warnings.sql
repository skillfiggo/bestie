-- ============================================
-- COMPLETE FIX FOR ALL SEARCH PATH WARNINGS
-- Run this entire script in Supabase SQL Editor
-- ============================================

-- ============================================
-- DROP EXISTING FUNCTIONS (to handle signature changes)
-- ============================================
DROP FUNCTION IF EXISTS send_official_message(uuid, text);
DROP FUNCTION IF EXISTS process_earning_transfer(uuid, uuid, int);
DROP FUNCTION IF EXISTS submit_withdrawal_request(numeric, text, text, text);
DROP FUNCTION IF EXISTS increment_moment_likes(uuid);
DROP FUNCTION IF EXISTS decrement_moment_likes(uuid);
DROP FUNCTION IF EXISTS decrement_likes(text, uuid);
DROP FUNCTION IF EXISTS get_nearby_profiles(double precision, double precision, double precision, text);
DROP FUNCTION IF EXISTS generate_unique_bestie_id();
DROP FUNCTION IF EXISTS handle_new_user();
DROP FUNCTION IF EXISTS handle_new_user_simple();
DROP FUNCTION IF EXISTS handle_new_user_debug();
DROP FUNCTION IF EXISTS update_chat_streak(uuid);
DROP FUNCTION IF EXISTS increment_chat_coins(uuid, integer);
DROP FUNCTION IF EXISTS process_successful_payment(uuid, text, numeric, int, text);

-- ============================================
-- 1. CHAT & STREAK FUNCTIONS
-- ============================================

CREATE OR REPLACE FUNCTION update_chat_streak(target_chat_id uuid)
RETURNS VOID AS $$
DECLARE
    curr_streak int;
    last_update timestamp with time zone;
    now_ts timestamp with time zone;
    days_diff int;
BEGIN
    SELECT streak_count, last_streak_update INTO curr_streak, last_update
    FROM public.chats WHERE id = target_chat_id;

    now_ts := now();
    
    IF last_update IS NULL THEN
        UPDATE public.chats 
        SET streak_count = 1, last_streak_update = now_ts 
        WHERE id = target_chat_id;
        RETURN;
    END IF;

    days_diff := date(now_ts) - date(last_update);

    IF days_diff = 0 THEN
        UPDATE public.chats SET last_streak_update = now_ts WHERE id = target_chat_id;
    ELSIF days_diff = 1 THEN
        UPDATE public.chats 
        SET streak_count = curr_streak + 1, last_streak_update = now_ts 
        WHERE id = target_chat_id;
    ELSE
        UPDATE public.chats 
        SET streak_count = 1, last_streak_update = now_ts 
        WHERE id = target_chat_id;
    END IF;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public;

CREATE OR REPLACE FUNCTION increment_chat_coins(
  target_chat_id UUID,
  coin_amount INTEGER DEFAULT 10
)
RETURNS VOID AS $$
BEGIN
  UPDATE chats
  SET coins_spent = coins_spent + coin_amount
  WHERE id = target_chat_id;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public;

-- ============================================
-- 2. PAYMENT & EARNING FUNCTIONS
-- ============================================

CREATE OR REPLACE FUNCTION process_successful_payment(
  p_user_id uuid,
  p_reference text,
  p_amount numeric,
  p_coins int,
  p_provider text
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_balance int;
  v_msg text;
BEGIN
  -- 1. Insert into history
  INSERT INTO payment_history (user_id, reference, provider, amount, coins_added)
  VALUES (p_user_id, p_reference, p_provider, p_amount, p_coins);

  -- 2. Update Profile coins
  UPDATE profiles
  SET coins = coins + p_coins
  WHERE id = p_user_id
  RETURNING coins INTO v_new_balance;

  -- 3. Send Official Notification
  v_msg := '🎉 Recharge Successful! You have received ' || p_coins || ' coins. Your new balance is ' || v_new_balance || ' coins.';
  PERFORM send_official_message(p_user_id, v_msg);

  RETURN v_new_balance;
END;
$$;

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
  -- Calculate diamonds (40% of coins)
  v_diamonds_earned := FLOOR(p_coins_spent * 0.4);
  
  -- Add diamonds to receiver
  UPDATE profiles
  SET diamonds = diamonds + v_diamonds_earned
  WHERE id = p_receiver_id;
  
  -- Log the earning
  INSERT INTO earnings_history (receiver_id, source_type, source_id, coins_received, diamonds_earned)
  VALUES (p_receiver_id, 'call', p_call_id, p_coins_spent, v_diamonds_earned);
END;
$$;

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

-- ============================================
-- 3. MOMENT & LIKE FUNCTIONS
-- ============================================

CREATE OR REPLACE FUNCTION increment_moment_likes(row_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE moments
  SET like_count = like_count + 1
  WHERE id = row_id;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_moment_likes(row_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE moments
  SET like_count = GREATEST(like_count - 1, 0)
  WHERE id = row_id;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_likes(t_name TEXT, row_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  EXECUTE format('UPDATE %I SET like_count = GREATEST(like_count - 1, 0) WHERE id = $1', t_name)
  USING row_id;
END;
$$;

-- ============================================
-- 4. LOCATION & NEARBY FUNCTIONS
-- ============================================

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
-- 5. USER SIGNUP & ID GENERATION
-- ============================================

CREATE OR REPLACE FUNCTION generate_unique_bestie_id()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  result TEXT := '';
  i INTEGER := 0;
  exists_count INTEGER;
BEGIN
  LOOP
    result := '';
    FOR i IN 1..5 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    
    SELECT count(*) INTO exists_count FROM profiles WHERE bestie_id = result;
    IF exists_count = 0 THEN
      RETURN result;
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  team_id UUID;
  new_bestie_id TEXT;
BEGIN
  -- Generate unique ID
  new_bestie_id := generate_unique_bestie_id();

  -- Create Profile
  INSERT INTO public.profiles (id, name, age, gender, bestie_id, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'New User'),
    COALESCE((NEW.raw_user_meta_data->>'age')::INTEGER, 18),
    COALESCE(NEW.raw_user_meta_data->>'gender', 'other'),
    new_bestie_id,
    NOW(),
    NOW()
  );

  -- Find Official Team
  BEGIN
    SELECT id INTO team_id FROM profiles WHERE name = 'Official Team' LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    team_id := NULL;
  END;

  -- Create Official Chat
  IF team_id IS NOT NULL AND team_id != NEW.id THEN
    BEGIN
      INSERT INTO public.chats (user1_id, user2_id, last_message, last_message_time)
      VALUES (
        NEW.id,
        team_id,
        'Welcome to Bestie! This is the official support channel.',
        NOW()
      );
    EXCEPTION WHEN OTHERS THEN
      -- Continue if chat creation fails
    END;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION handle_new_user_simple()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_bestie_id TEXT;
BEGIN
  new_bestie_id := generate_unique_bestie_id();

  INSERT INTO public.profiles (id, name, age, gender, bestie_id, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'New User'),
    COALESCE((NEW.raw_user_meta_data->>'age')::INTEGER, 18),
    COALESCE(NEW.raw_user_meta_data->>'gender', 'other'),
    new_bestie_id,
    NOW(),
    NOW()
  );

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION handle_new_user_debug()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_bestie_id TEXT;
BEGIN
  new_bestie_id := generate_unique_bestie_id();

  INSERT INTO public.profiles (id, name, age, gender, bestie_id, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'New User'),
    COALESCE((NEW.raw_user_meta_data->>'age')::INTEGER, 18),
    COALESCE(NEW.raw_user_meta_data->>'gender', 'other'),
    new_bestie_id,
    NOW(),
    NOW()
  );

  RAISE NOTICE 'Profile created for user %', NEW.id;
  
  RETURN NEW;
END;
$$;

-- ============================================
-- 6. OFFICIAL MESSAGING
-- ============================================

CREATE OR REPLACE FUNCTION send_official_message(
  target_user_id UUID,
  message_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  official_id UUID := '00000000-0000-0000-0000-000000000001';
  chat_id UUID;
BEGIN
  -- 1. Check if chat exists
  SELECT id INTO chat_id
  FROM chats
  WHERE (user1_id = official_id AND user2_id = target_user_id)
     OR (user1_id = target_user_id AND user2_id = official_id)
  LIMIT 1;

  -- 2. If no chat, create one
  IF chat_id IS NULL THEN
    INSERT INTO chats (user1_id, user2_id, last_message, last_message_time)
    VALUES (official_id, target_user_id, 'Chat started', NOW())
    RETURNING id INTO chat_id;
  END IF;

  -- 3. Insert Message
  INSERT INTO messages (chat_id, sender_id, receiver_id, content, message_type, status)
  VALUES (
    chat_id,
    official_id,
    target_user_id,
    message_content,
    'text',
    'sent'
  );

  -- 4. Update Chat Last Message
  UPDATE chats
  SET last_message = message_content,
      last_message_time = NOW()
  WHERE id = chat_id;

  RETURN jsonb_build_object('success', true, 'chat_id', chat_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- ============================================
-- 7. UTILITY FUNCTIONS
-- ============================================

CREATE OR REPLACE FUNCTION update_reports_updated_at()
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

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '✅ All functions updated with SET search_path = public';
  RAISE NOTICE '🔒 Security warnings should now be resolved';
END $$;

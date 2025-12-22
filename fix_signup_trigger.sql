-- ============================================
-- FIX SIGNUP TRIGGER
-- ============================================
-- 1. Add bestie_id column if not exists
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bestie_id TEXT UNIQUE;

-- 2. Function to generate unique 5 char bestie_id
CREATE OR REPLACE FUNCTION generate_unique_bestie_id()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  result TEXT := '';
  i INTEGER := 0;
  param_id TEXT;
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
$$ LANGUAGE plpgsql;

-- 3. Update handle_new_user to include bestie_id
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  team_id UUID;
  new_bestie_id TEXT;
BEGIN
  -- Generate unique ID
  new_bestie_id := generate_unique_bestie_id();

  -- 1. Create Profile
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

  -- 2. Find Official Team ID (Must be created manually first!)
  SELECT id INTO team_id FROM profiles WHERE name = 'Official Team' LIMIT 1;

  -- 3. If Team exists and is not this user, create a chat
  IF team_id IS NOT NULL AND team_id != NEW.id THEN
    INSERT INTO public.chats (user1_id, user2_id, last_message, last_message_time)
    VALUES (
      NEW.id,
      team_id,
      'Welcome to Bestie! This is the official support channel.',
      NOW()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

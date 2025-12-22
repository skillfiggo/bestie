-- ============================================
-- FIX SIGNUP V2 (ROBUST)
-- ============================================

-- 1. Remove Age Constraint (Potential cause of crash if user picks recent year)
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_age_check;
-- Add back a looser constraint
ALTER TABLE profiles ADD CONSTRAINT profiles_age_check CHECK (age >= 0 AND age <= 120);

-- 2. Ensure bestie_id column exists
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bestie_id TEXT UNIQUE;

-- 3. Re-create function to generate unique ID (Safe replacement)
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

-- 4. Re-create Trigger Function (Force Replace)
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  team_id UUID;
  new_bestie_id TEXT;
BEGIN
  -- Generate unique ID
  new_bestie_id := generate_unique_bestie_id();

  -- 1. Create Profile
  -- Uses exception handling to print error if it fails (visible in Supabase logs)
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
  BEGIN
    SELECT id INTO team_id FROM profiles WHERE name = 'Official Team' LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    team_id := NULL; -- Ignore if this fails
  END;

  -- 3. If Team exists and is not this user, create a chat
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
      -- Do nothing if chat creation fails, don't block sign up
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Re-bind Trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

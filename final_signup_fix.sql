-- ============================================
-- FINAL SIGNUP FIX (ALL-IN-ONE)
-- ============================================

-- 1. Ensure bestie_id column exists
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bestie_id TEXT UNIQUE;

-- 2. Define Generator Function
CREATE OR REPLACE FUNCTION generate_unique_bestie_id()
RETURNS TEXT AS $$
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
$$ LANGUAGE plpgsql;

-- 3. Cleanup Old Triggers/Constraints
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
SELECT CASE WHEN EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_age_check'
) THEN
    'ALTER TABLE profiles DROP CONSTRAINT profiles_age_check'
END;
-- Relax age constraint
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_age_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_age_check CHECK (age >= 0);

-- 4. Define Simplified Trigger Logic
CREATE OR REPLACE FUNCTION handle_new_user_simple()
RETURNS TRIGGER AS $$
DECLARE
  new_bestie_id TEXT;
BEGIN
  -- Generate unique ID
  new_bestie_id := generate_unique_bestie_id();

  -- Insert with safe defaults
  INSERT INTO public.profiles (id, bestie_id, name, age, gender)
  VALUES (
    NEW.id,
    new_bestie_id,
    'New User',
    18,
    'other'
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Bind Trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user_simple();

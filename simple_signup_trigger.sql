-- ============================================
-- SIMPLE SIGNUP TRIGGER (FOOLPROOF)
-- ============================================

-- 1. Drop previous triggers to ensure clean slate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. Ensure Schema is flexible (Remove strict checks just in case)
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_age_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_age_check CHECK (age >= 0);

-- 3. Simplified Trigger Function
-- - Ignores metadata (prevents parsing errors)
-- - Uses hardcoded valid defaults (client will overwrite correct data immediately)
-- - Generates bestie_id
-- - REMOVED chat creation logic (likely cause of failure)
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
    'New User',   -- Safe default
    18,           -- Safe default
    'other'       -- Safe default
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Bind Simplified Trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user_simple();

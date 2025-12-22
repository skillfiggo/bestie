-- ============================================
-- DEBUG LOGGING SETUP
-- ============================================

-- 1. Create a log table
CREATE TABLE IF NOT EXISTS public.debug_logs (
  id UUID DEFAULT uuid_generate_v4(),
  message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.debug_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public Read" ON public.debug_logs;
CREATE POLICY "Public Read" ON public.debug_logs FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public Insert" ON public.debug_logs;
CREATE POLICY "Public Insert" ON public.debug_logs FOR INSERT WITH CHECK (true);

-- 2. Update Generator to be safe
CREATE OR REPLACE FUNCTION generate_unique_bestie_id()
RETURNS TEXT AS $$
BEGIN
  -- Simple random string
  RETURN substr(md5(random()::text), 1, 5);
END;
$$ LANGUAGE plpgsql;

-- 3. Debug Trigger Function
CREATE OR REPLACE FUNCTION handle_new_user_debug()
RETURNS TRIGGER AS $$
DECLARE
  new_bestie_id TEXT;
BEGIN
  INSERT INTO public.debug_logs (message) VALUES ('Trigger Started for User: ' || NEW.id);
  
  -- Generate ID
  new_bestie_id := generate_unique_bestie_id();
  INSERT INTO public.debug_logs (message) VALUES ('Generated ID: ' || new_bestie_id);

  -- Attempt Insert
  BEGIN
    INSERT INTO public.profiles (id, bestie_id, name, age, gender)
    VALUES (
      NEW.id,
      new_bestie_id,
      'New User',
      18,
      'other'
    )
    ON CONFLICT (id) DO NOTHING;
    
    INSERT INTO public.debug_logs (message) VALUES ('Insert Success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO public.debug_logs (message) VALUES ('Insert Failed: ' || SQLERRM);
    RAISE; -- Re-throw error to fail the transaction (or suppress if you want)
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Bind Debug Trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user_debug();

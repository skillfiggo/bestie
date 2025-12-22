-- ============================================
-- DIAGNOSTIC: TEST PROFILE INSERT
-- ============================================

DO $$
DECLARE
  dummy_id UUID := '00000000-0000-0000-0000-000000000001'; -- Safe dummy UUID
BEGIN
  RAISE NOTICE '1. Attempting to insert dummy profile...';
  
  -- Attempt insert similar to the trigger
  INSERT INTO public.profiles (id, bestie_id, name, age, gender)
  VALUES (
    dummy_id,
    'DEBUG' || floor(random()*1000)::text,
    'Debug User',
    25,
    'other'
  )
  ON CONFLICT (id) DO UPDATE SET name = 'Debug Updated'; -- upsert just in case
  
  RAISE NOTICE '2. Insert/Upsert Successful!';
  
  -- Clean up
  DELETE FROM public.profiles WHERE id = dummy_id;
  RAISE NOTICE '3. Cleanup Successful!';

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'INSERT FAILED! Error: %', SQLERRM;
END $$;

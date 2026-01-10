-- ============================================
-- FIX MOMENT LIKES DUPLICATION
-- ============================================

-- 1. Remove duplicate likes if any exist (keep only the oldest one)
DELETE FROM moment_likes a
USING moment_likes b
WHERE a.id > b.id
  AND a.user_id = b.user_id
  AND a.moment_id = b.moment_id;

-- 2. Add unique constraint to prevent future duplication
-- First check if constraint exists, if not add it.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'moment_likes_user_moment_unique'
    ) THEN
        ALTER TABLE moment_likes ADD CONSTRAINT moment_likes_user_moment_unique UNIQUE (user_id, moment_id);
    END IF;
END $$;

-- 3. Recount likes for all moments to ensure accuracy
UPDATE moments m
SET likes_count = (
  SELECT count(*)
  FROM moment_likes ml
  WHERE ml.moment_id = m.id
);

-- 4. Create or Update RPC for incrementing likes safely
CREATE OR REPLACE FUNCTION increment_moment_likes(row_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE moments
  SET likes_count = likes_count + 1
  WHERE id = row_id;
END;
$$ LANGUAGE plpgsql;

-- 5. Create or Update RPC for decrementing likes safely
CREATE OR REPLACE FUNCTION decrement_moment_likes(row_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE moments
  SET likes_count = GREATEST(0, likes_count - 1)
  WHERE id = row_id;
END;
$$ LANGUAGE plpgsql;

-- 6. Generic decrement function used in some parts of the app
CREATE OR REPLACE FUNCTION decrement_likes(t_name TEXT, row_id UUID)
RETURNS void AS $$
BEGIN
  EXECUTE format('UPDATE %I SET likes_count = GREATEST(0, likes_count - 1) WHERE id = $1', t_name)
  USING row_id;
END;
$$ LANGUAGE plpgsql;

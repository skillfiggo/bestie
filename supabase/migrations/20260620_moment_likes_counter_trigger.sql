-- ============================================================
-- Moment Likes Counter Trigger
-- Automatically maintains likes_count on the moments table
-- when rows are inserted or deleted from moment_likes.
-- This replaces the fragile RPC-based approach in the app.
-- ============================================================

-- Ensure likes_count column exists with a default of 0
ALTER TABLE moments ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0;

-- ─────────────────────────────────────────────────────────────
-- Function: update likes_count on the moments table
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_moment_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE moments
    SET likes_count = likes_count + 1
    WHERE id = NEW.moment_id;
    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    UPDATE moments
    SET likes_count = GREATEST(likes_count - 1, 0)
    WHERE id = OLD.moment_id;
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- Trigger: fires after every INSERT or DELETE on moment_likes
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS on_moment_like_change ON moment_likes;
CREATE TRIGGER on_moment_like_change
  AFTER INSERT OR DELETE ON moment_likes
  FOR EACH ROW
  EXECUTE FUNCTION update_moment_likes_count();

-- ─────────────────────────────────────────────────────────────
-- Back-fill: recalculate counts for all existing moments
-- so historical data is accurate immediately.
-- ─────────────────────────────────────────────────────────────
UPDATE moments m
SET likes_count = (
  SELECT COUNT(*) FROM moment_likes ml WHERE ml.moment_id = m.id
);

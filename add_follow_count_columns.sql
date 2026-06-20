-- Add follower and following count columns to profiles table
-- This fixes the "column does not exist" error when viewing profiles

-- Option 1: Add actual columns (will be manually updated or via triggers)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS follower_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS following_count INTEGER DEFAULT 0;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_follower_count ON profiles(follower_count DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_following_count ON profiles(following_count DESC);

-- Create a function to update follower/following counts
CREATE OR REPLACE FUNCTION update_follow_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update follower count for the user being followed
  UPDATE profiles
  SET follower_count = (
    SELECT COUNT(*) 
    FROM follows 
    WHERE following_id = COALESCE(NEW.following_id, OLD.following_id)
  )
  WHERE id = COALESCE(NEW.following_id, OLD.following_id);

  -- Update following count for the user who is following
  UPDATE profiles
  SET following_count = (
    SELECT COUNT(*) 
    FROM follows 
    WHERE follower_id = COALESCE(NEW.follower_id, OLD.follower_id)
  )
  WHERE id = COALESCE(NEW.follower_id, OLD.follower_id);

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Create triggers to automatically update counts
DROP TRIGGER IF EXISTS update_follow_counts_on_insert ON follows;
CREATE TRIGGER update_follow_counts_on_insert
  AFTER INSERT ON follows
  FOR EACH ROW
  EXECUTE FUNCTION update_follow_counts();

DROP TRIGGER IF EXISTS update_follow_counts_on_delete ON follows;
CREATE TRIGGER update_follow_counts_on_delete
  AFTER DELETE ON follows
  FOR EACH ROW
  EXECUTE FUNCTION update_follow_counts();

-- Initialize existing counts (one-time update for existing data)
UPDATE profiles p
SET 
  follower_count = (SELECT COUNT(*) FROM follows WHERE following_id = p.id),
  following_count = (SELECT COUNT(*) FROM follows WHERE follower_id = p.id);

-- Success message
SELECT 'Follower and following count columns added successfully!' AS status;

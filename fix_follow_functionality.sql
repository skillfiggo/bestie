-- Fix Follow Functionality Issues
-- This script ensures the follows table and RLS policies are correctly configured

-- 1. Drop existing policies to avoid conflicts (including new names)
DROP POLICY IF EXISTS "Users can view all follows" ON follows;
DROP POLICY IF EXISTS "Users can follow others" ON follows;
DROP POLICY IF EXISTS "Users can unfollow" ON follows;
DROP POLICY IF EXISTS "Anyone can view follows" ON follows;
DROP POLICY IF EXISTS "Users can create their own follows" ON follows;
DROP POLICY IF EXISTS "Users can delete their own follows" ON follows;

-- 2. Ensure RLS is enabled
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

-- 3. Create a comprehensive SELECT policy (users can view all follows - public)
CREATE POLICY "Anyone can view follows"
ON follows
FOR SELECT
TO authenticated
USING (true);

-- 4. Create INSERT policy (users can only create follows where they are the follower)
CREATE POLICY "Users can create their own follows"
ON follows
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = follower_id
  AND follower_id != following_id  -- Prevent self-following
);

-- 5. Create DELETE policy (users can only delete their own follows)
CREATE POLICY "Users can delete their own follows"
ON follows
FOR DELETE
TO authenticated
USING (auth.uid() = follower_id);

-- 6. Verify table structure
DO $$
BEGIN
  -- Check if unique constraint exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'follows_follower_id_following_id_key'
  ) THEN
    ALTER TABLE follows ADD CONSTRAINT follows_follower_id_following_id_key 
      UNIQUE (follower_id, following_id);
  END IF;

  -- Check if check constraint exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'follows_check'
  ) THEN
    ALTER TABLE follows ADD CONSTRAINT follows_check 
      CHECK (follower_id != following_id);
  END IF;
END $$;

-- 7. Ensure indexes exist for performance
CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);
CREATE INDEX IF NOT EXISTS idx_follows_created_at ON follows(created_at DESC);

-- 8. Grant necessary permissions
GRANT SELECT, INSERT, DELETE ON follows TO authenticated;

-- Success message
SELECT 'Follow functionality has been fixed! Policies recreated successfully.' AS status;

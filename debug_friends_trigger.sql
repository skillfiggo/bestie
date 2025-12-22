-- ============================================
-- DEBUG & FIX FRIENDSHIP LOGIC
-- ============================================

-- 1. Check if trigger exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_follow_created') THEN
    RAISE EXCEPTION 'Trigger on_follow_created does not exist! Please run social_logic.sql again.';
  END IF;
  RAISE NOTICE 'Trigger on_follow_created exists.';
END $$;

-- 2. Force Backfill Mutual Follows (Fixes existing missing friendships)
INSERT INTO friendships (user1_id, user2_id, status, friendship_type, streak)
SELECT 
  f1.follower_id, 
  f1.following_id, 
  'accepted', 
  'friend', 
  0
FROM follows f1
JOIN follows f2 ON f1.follower_id = f2.following_id AND f1.following_id = f2.follower_id
WHERE f1.follower_id < f1.following_id -- Prevent duplicates (A-B vs B-A)
AND NOT EXISTS (
  SELECT 1 FROM friendships fr 
  WHERE (fr.user1_id = f1.follower_id AND fr.user2_id = f1.following_id)
     OR (fr.user1_id = f1.following_id AND fr.user2_id = f1.follower_id)
);

-- 3. Verify Constraints
-- Ensure no RLS blocks inserts by checking policies
DO $$
BEGIN
  -- Just a check, actual RLS change requires ALTER POLICY
  RAISE NOTICE 'Backfill complete. If issues persist, check RLS on friendships table.';
END $$;

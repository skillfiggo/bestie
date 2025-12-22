-- ============================================
-- SOCIAL LOGIC: MUTUAL FOLLOWS & STREAKS
-- ============================================

-- 1. Add streak column to friendships
ALTER TABLE friendships ADD COLUMN IF NOT EXISTS streak INTEGER DEFAULT 0;

-- 2. Function to handle Mutual Follows -> Friend
CREATE OR REPLACE FUNCTION handle_follow_change()
RETURNS TRIGGER AS $$
DECLARE
  is_mutual BOOLEAN;
  existing_friendship UUID;
BEGIN
  -- Check if the person being followed also follows the new follower
  SELECT EXISTS(
    SELECT 1 FROM follows 
    WHERE follower_id = NEW.following_id 
    AND following_id = NEW.follower_id
  ) INTO is_mutual;

  IF is_mutual THEN
    -- Check if friendship already exists
    SELECT id INTO existing_friendship FROM friendships 
    WHERE (user1_id = NEW.follower_id AND user2_id = NEW.following_id)
       OR (user1_id = NEW.following_id AND user2_id = NEW.follower_id);
       
    IF existing_friendship IS NULL THEN
      -- Create new friendship
      INSERT INTO friendships (user1_id, user2_id, status, friendship_type, streak)
      VALUES (NEW.follower_id, NEW.following_id, 'accepted', 'friend', 0);
    ELSE
      -- Update status if pending/blocked
      UPDATE friendships 
      SET status = 'accepted'
      WHERE id = existing_friendship;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on Follows
DROP TRIGGER IF EXISTS on_follow_created ON follows;
CREATE TRIGGER on_follow_created
  AFTER INSERT ON follows
  FOR EACH ROW
  EXECUTE FUNCTION handle_follow_change();


-- 3. Function to handle Unfollow -> Remove Friend (Optional, but logical)
CREATE OR REPLACE FUNCTION handle_unfollow_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete friendship if one side unfollows
  DELETE FROM friendships 
  WHERE (user1_id = OLD.follower_id AND user2_id = OLD.following_id)
     OR (user1_id = OLD.following_id AND user2_id = OLD.follower_id);
     
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on Unfollow
DROP TRIGGER IF EXISTS on_follow_deleted ON follows;
CREATE TRIGGER on_follow_deleted
  AFTER DELETE ON follows
  FOR EACH ROW
  EXECUTE FUNCTION handle_unfollow_change();


-- 4. Function to handle Streaks (On New Message)
CREATE OR REPLACE FUNCTION handle_message_streak()
RETURNS TRIGGER AS $$
DECLARE
  friendship_rec RECORD;
BEGIN
  -- Find friendship between sender and receiver
  SELECT * INTO friendship_rec FROM friendships 
  WHERE (user1_id = NEW.sender_id AND user2_id = NEW.receiver_id)
     OR (user1_id = NEW.receiver_id AND user2_id = NEW.sender_id)
  LIMIT 1;
  
  IF friendship_rec.id IS NOT NULL THEN
    -- Increment Streak
    UPDATE friendships
    SET streak = streak + 1,
        -- Upgrade to BESTIE if streak hits 100
        friendship_type = CASE 
          WHEN (streak + 1) >= 100 THEN 'bestie' 
          ELSE friendship_type 
        END
    WHERE id = friendship_rec.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on Messages
DROP TRIGGER IF EXISTS on_message_created ON messages;
CREATE TRIGGER on_message_created
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION handle_message_streak();

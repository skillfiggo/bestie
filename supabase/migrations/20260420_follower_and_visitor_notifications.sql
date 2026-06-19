-- ============================================================
-- Follower & Profile View Notifications
-- Sends push notification + Official Team in-app message
-- when a user gets a new follower OR someone views their profile.
-- Depends on: send_push_notification(), send_official_message()
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1.  Trigger: New Follow → notify the person being followed
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_new_follower()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  follower_name   TEXT;
  following_token TEXT;   -- FCM token of the person who just gained a follower
  official_id     UUID := '00000000-0000-0000-0000-000000000001';
  chat_id         UUID;
  msg_text        TEXT;
BEGIN
  -- Don't notify if the Official Team account "follows" someone
  IF NEW.follower_id = official_id THEN
    RETURN NEW;
  END IF;

  -- Fetch follower's name and the following user's FCM token
  SELECT p_follower.name, p_following.fcm_token
  INTO   follower_name, following_token
  FROM   profiles p_follower
  JOIN   profiles p_following ON p_following.id = NEW.following_id
  WHERE  p_follower.id = NEW.follower_id;

  -- ── Push notification ──────────────────────────────────────
  PERFORM send_push_notification(
    following_token,
    'New Follower! 🎉',
    follower_name || ' started following you',
    jsonb_build_object(
      'type',        'new_follower',
      'follower_id', NEW.follower_id
    )
  );

  -- ── Official Team in-app message ───────────────────────────
  msg_text := '🎉 ' || follower_name || ' just started following you!';

  -- Find or create the Official Team chat for this user
  SELECT id INTO chat_id
  FROM   chats
  WHERE  (user1_id = official_id AND user2_id = NEW.following_id)
     OR  (user1_id = NEW.following_id AND user2_id = official_id)
  LIMIT  1;

  IF chat_id IS NULL THEN
    INSERT INTO chats (user1_id, user2_id, last_message, last_message_time)
    VALUES (official_id, NEW.following_id, msg_text, NOW())
    RETURNING id INTO chat_id;
  END IF;

  INSERT INTO messages (chat_id, sender_id, receiver_id, content, message_type, status)
  VALUES (chat_id, official_id, NEW.following_id, msg_text, 'text', 'sent');

  UPDATE chats
     SET last_message      = msg_text,
         last_message_time = NOW()
   WHERE id = chat_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_on_new_follower failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_follower_notify ON follows;
CREATE TRIGGER on_new_follower_notify
  AFTER INSERT ON follows
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_new_follower();


-- ─────────────────────────────────────────────────────────────
-- 2.  Trigger: Profile Viewed → notify the profile owner
--     Uses the existing `visitors` table:
--       visitor_id  → who viewed
--       visited_id  → who was viewed (gets notified)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_profile_view()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  visitor_name   TEXT;
  visited_token  TEXT;   -- FCM token of the profile owner
  official_id    UUID := '00000000-0000-0000-0000-000000000001';
  chat_id        UUID;
  msg_text       TEXT;
  recent_view    BOOLEAN;
BEGIN
  -- Don't notify if someone views the Official Team profile
  IF NEW.visited_id = official_id THEN
    RETURN NEW;
  END IF;

  -- Don't notify if a user views their own profile
  IF NEW.visitor_id = NEW.visited_id THEN
    RETURN NEW;
  END IF;

  -- Throttle: only notify once per hour per visitor/visited pair
  -- to avoid spamming when someone repeatedly opens a profile
  SELECT EXISTS (
    SELECT 1
    FROM   visitors
    WHERE  visitor_id  = NEW.visitor_id
      AND  visited_id  = NEW.visited_id
      AND  visited_at >= NOW() - INTERVAL '1 hour'
      AND  id         != NEW.id   -- exclude the row just inserted
  ) INTO recent_view;

  IF recent_view THEN
    RETURN NEW;
  END IF;

  -- Fetch visitor's name and visited user's FCM token
  SELECT p_visitor.name, p_visited.fcm_token
  INTO   visitor_name, visited_token
  FROM   profiles p_visitor
  JOIN   profiles p_visited ON p_visited.id = NEW.visited_id
  WHERE  p_visitor.id = NEW.visitor_id;

  -- ── Push notification ──────────────────────────────────────
  PERFORM send_push_notification(
    visited_token,
    'Someone viewed your profile 👀',
    visitor_name || ' checked out your profile',
    jsonb_build_object(
      'type',       'profile_view',
      'visitor_id', NEW.visitor_id
    )
  );

  -- ── Official Team in-app message ───────────────────────────
  msg_text := '👀 ' || visitor_name || ' just viewed your profile!';

  -- Find or create the Official Team chat for this user
  SELECT id INTO chat_id
  FROM   chats
  WHERE  (user1_id = official_id AND user2_id = NEW.visited_id)
     OR  (user1_id = NEW.visited_id AND user2_id = official_id)
  LIMIT  1;

  IF chat_id IS NULL THEN
    INSERT INTO chats (user1_id, user2_id, last_message, last_message_time)
    VALUES (official_id, NEW.visited_id, msg_text, NOW())
    RETURNING id INTO chat_id;
  END IF;

  INSERT INTO messages (chat_id, sender_id, receiver_id, content, message_type, status)
  VALUES (chat_id, official_id, NEW.visited_id, msg_text, 'text', 'sent');

  UPDATE chats
     SET last_message      = msg_text,
         last_message_time = NOW()
   WHERE id = chat_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_on_profile_view failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_profile_view_notify ON visitors;
CREATE TRIGGER on_profile_view_notify
  AFTER INSERT ON visitors
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_profile_view();

-- ============================================================
-- Push Notification Triggers
-- Run this in Supabase SQL Editor or as a migration
-- Requires: pg_net extension (enable via Database > Extensions)
-- ============================================================

-- 0. Enable pg_net (if not already enabled)
-- In the Dashboard: Database → Extensions → search "pg_net" → Enable
-- Or uncomment the line below:
-- CREATE EXTENSION IF NOT EXISTS pg_net;

-- 1. Add FCM token column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- ─────────────────────────────────────────────────────────────
-- 2. Helper function: fire a push notification via Edge Function
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION send_push_notification(
  p_token    TEXT,
  p_title    TEXT,
  p_body     TEXT,
  p_data     JSONB DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  -- ⚠️ Replace with your actual Supabase Project URL
  supabase_url TEXT := 'https://yuvxxcialdbdkmleqksa.supabase.co';
  -- ⚠️ Replace with your actual Service Role Key
  service_key  TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1dnh4Y2lhbGRiZGttbGVxa3NhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NTI3MzYxNiwiZXhwIjoyMDgwODQ5NjE2fQ.NKqvAr1ceCkeB5SGPwB_J2GOaTid58lhD0aUMUFeDdc';
BEGIN
  IF p_token IS NULL OR p_token = '' THEN
    RETURN;
  END IF;

  PERFORM net.http_post(
    url     := supabase_url || '/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body    := jsonb_build_object(
      'token', p_token,
      'title', p_title,
      'body',  p_body,
      'data',  p_data
    )
  );
EXCEPTION WHEN OTHERS THEN
  -- Never let notification errors break the main transaction
  RAISE WARNING 'send_push_notification failed: %', SQLERRM;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 3. Trigger: New Chat Message → notify receiver
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  receiver_token TEXT;
  sender_name    TEXT;
  notif_body     TEXT;
BEGIN
  -- Skip system messages (deductCost = false marks these)
  IF NEW.message_type = 'system' THEN
    RETURN NEW;
  END IF;

  -- Get sender name and receiver's FCM token in one step
  SELECT p_sender.name, p_receiver.fcm_token
  INTO sender_name, receiver_token
  FROM profiles p_sender
  JOIN profiles p_receiver ON p_receiver.id = NEW.receiver_id
  WHERE p_sender.id = NEW.sender_id;

  -- Build the body preview
  notif_body := CASE NEW.message_type
    WHEN 'voice' THEN '🎤 Sent you a voice message'
    WHEN 'image' THEN '📷 Sent you an image'
    ELSE LEFT(NEW.content, 100)  -- Truncate long messages
  END;

  PERFORM send_push_notification(
    receiver_token,
    sender_name,
    notif_body,
    jsonb_build_object(
      'type',    'message',
      'chat_id', NEW.chat_id
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_message_notify ON messages;
CREATE TRIGGER on_new_message_notify
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_new_message();

-- ─────────────────────────────────────────────────────────────
-- 4. Trigger: Incoming Call → notify receiver
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_incoming_call()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  receiver_token TEXT;
  caller_name    TEXT;
  call_type      TEXT;
BEGIN
  -- Only notify on new "calling" status
  IF NEW.status != 'calling' THEN
    RETURN NEW;
  END IF;

  SELECT p_caller.name, p_receiver.fcm_token
  INTO caller_name, receiver_token
  FROM profiles p_caller
  JOIN profiles p_receiver ON p_receiver.id = NEW.receiver_id
  WHERE p_caller.id = NEW.caller_id;

  call_type := CASE WHEN NEW.media_type = 'video' THEN '📹 Video Call' ELSE '📞 Voice Call' END;

  PERFORM send_push_notification(
    receiver_token,
    caller_name,
    'Incoming ' || call_type,
    jsonb_build_object(
      'type',       'call',
      'channel_id', NEW.channel_id,
      'caller_id',  NEW.caller_id,
      'media_type', NEW.media_type,
      'call_id',    NEW.id
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_incoming_call_notify ON call_history;
CREATE TRIGGER on_incoming_call_notify
  AFTER INSERT ON call_history
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_incoming_call();

-- ─────────────────────────────────────────────────────────────
-- 5. Trigger: New Like → notify moment author
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_new_like()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  author_token TEXT;
  liker_name   TEXT;
  author_id    UUID;
BEGIN
  -- Get the moment author
  SELECT user_id INTO author_id FROM moments WHERE id = NEW.moment_id;

  -- Don't notify if you liked your own post
  IF author_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  SELECT p_liker.name, p_author.fcm_token
  INTO liker_name, author_token
  FROM profiles p_liker
  JOIN profiles p_author ON p_author.id = author_id
  WHERE p_liker.id = NEW.user_id;

  PERFORM send_push_notification(
    author_token,
    liker_name,
    'liked your post ❤️',
    jsonb_build_object(
      'type',      'like',
      'moment_id', NEW.moment_id
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_like_notify ON moment_likes;
CREATE TRIGGER on_new_like_notify
  AFTER INSERT ON moment_likes
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_new_like();

-- ─────────────────────────────────────────────────────────────
-- (Removed the ALTER DATABASE lines as they cause permission issues)
-- ─────────────────────────────────────────────────────────────

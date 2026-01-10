-- Migration: Add 3-day inactivity reset to streak system
-- New rule: If gap between messages > 3 days, coins_spent resets to 0.

-- 1. Ensure last_message_time is used to track inactivity
-- (This column already exists in the chats table)

-- 2. Update the increment function to handle reset logic
CREATE OR REPLACE FUNCTION increment_chat_coins(
  target_chat_id UUID,
  coin_amount INTEGER DEFAULT 10
)
RETURNS VOID AS $$
DECLARE
  last_activity TIMESTAMP WITH TIME ZONE;
BEGIN
  -- Get the last message time
  SELECT last_message_time INTO last_activity
  FROM chats
  WHERE id = target_chat_id;

  -- If last activity was more than 3 days ago, reset the streak
  -- 3 days = 72 hours
  IF last_activity IS NOT NULL AND (NOW() - last_activity) > INTERVAL '3 days' THEN
    UPDATE chats
    SET coins_spent = coin_amount -- Reset to just this current message's value
    WHERE id = target_chat_id;
  ELSE
    -- Normal increment
    UPDATE chats
    SET coins_spent = COALESCE(coins_spent, 0) + coin_amount
    WHERE id = target_chat_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

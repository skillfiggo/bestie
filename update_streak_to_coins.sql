-- Migration: Convert chat streak from day-based to coin-based system
-- New formula: 5000 coins spent = 100°C streak

-- 1. Add coins_spent column to chats table
ALTER TABLE chats ADD COLUMN IF NOT EXISTS coins_spent INTEGER DEFAULT 0;

-- 2. Remove old streak columns (optional, can keep for backward compatibility)
-- ALTER TABLE chats DROP COLUMN IF EXISTS streak_count;
-- ALTER TABLE chats DROP COLUMN IF EXISTS last_streak_update;

-- 3. Create function to increment coins spent and calculate streak temperature
CREATE OR REPLACE FUNCTION increment_chat_coins(
  target_chat_id UUID,
  coin_amount INTEGER DEFAULT 10
)
RETURNS VOID AS $$
BEGIN
  UPDATE chats
  SET coins_spent = coins_spent + coin_amount
  WHERE id = target_chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Drop old streak function if it exists
DROP FUNCTION IF EXISTS update_chat_streak(UUID);

-- 5. Grant execution permission
GRANT EXECUTE ON FUNCTION increment_chat_coins(UUID, INTEGER) TO authenticated;

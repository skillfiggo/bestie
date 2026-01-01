-- Add columns for daily free messages
ALTER TABLE profiles 
ADD COLUMN free_messages_count INTEGER DEFAULT 0,
ADD COLUMN last_check_in TIMESTAMP WITH TIME ZONE;

-- Optional: Create a function to handle safe check-in atomically (prevents double updates)
CREATE OR REPLACE FUNCTION handle_daily_checkin(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  last_date DATE;
  current_date DATE;
BEGIN
  -- Get the last check-in date
  SELECT date_trunc('day', last_check_in) INTO last_date
  FROM profiles
  WHERE id = target_user_id;

  SELECT date_trunc('day', NOW()) INTO current_date;

  -- If never checked in (null) or checked in on a previous day
  IF last_date IS NULL OR last_date < current_date THEN
    UPDATE profiles
    SET 
      free_messages_count = 5,
      last_check_in = NOW()
    WHERE id = target_user_id;
    RETURN TRUE;
  ELSE
    RETURN FALSE; -- Already checked in today
  END IF;
END;
$$;

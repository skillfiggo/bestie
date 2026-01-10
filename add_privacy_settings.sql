-- Add privacy settings columns to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_online_status BOOLEAN DEFAULT TRUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_last_seen BOOLEAN DEFAULT TRUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Create/Update a function to update the last_active_at timestamp
CREATE OR REPLACE FUNCTION update_last_active_at()
RETURNS TRIGGER AS $$
BEGIN
  -- We only update last_active_at if the user is performing some action
  -- This could be triggered by updates to the profile, or explicitly called
  NEW.last_active_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Although we have an updated_at trigger, last_active_at is more specific to user activity.
-- For now, we'll let the app update it explicitly or rely on updated_at if preferred.
-- But adding the column is the first step.

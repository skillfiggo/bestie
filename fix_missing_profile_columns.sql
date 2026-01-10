-- Migration to add missing columns to the profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS bestie_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user',
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active',
ADD COLUMN IF NOT EXISTS show_online_status BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS show_last_seen BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS free_messages_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_check_in TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- Create an index for last_active_at to help with discovery sorting if needed
CREATE INDEX IF NOT EXISTS idx_profiles_last_active_at ON profiles(last_active_at);

-- Generate Bestie IDs for existing users if any are null
UPDATE profiles SET bestie_id = substring(id::text from 1 for 8) WHERE bestie_id IS NULL;

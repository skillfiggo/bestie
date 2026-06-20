-- Add email column to profiles table for webhook user lookup
-- This is needed because Paystack webhooks only send customer email,
-- not the user's Supabase ID

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);

-- Populate email from auth.users for existing users
UPDATE profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id AND p.email IS NULL;

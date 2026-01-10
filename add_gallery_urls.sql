-- Add gallery_urls column to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gallery_urls TEXT[] DEFAULT '{}';

-- Allow users to update their own gallery urls
-- (This policy might already be covered by 'Users can update own profile' if it uses updates)
-- But ensuring RLS allows it is safe.

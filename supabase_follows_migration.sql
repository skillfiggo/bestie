-- ============================================
-- FOLLOWS TABLE - User Follow System
-- ============================================
-- Execute this SQL in your Supabase SQL Editor
-- Dashboard → SQL Editor → New Query
-- ============================================

-- Create follows table
CREATE TABLE IF NOT EXISTS follows (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(follower_id, following_id),
  CHECK (follower_id != following_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

-- Enable Row Level Security
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view all follows (public information)
CREATE POLICY "Users can view all follows" ON follows
  FOR SELECT USING (true);

-- Users can follow others (insert their own follows)
CREATE POLICY "Users can follow others" ON follows
  FOR INSERT WITH CHECK (auth.uid() = follower_id);

-- Users can unfollow (delete their own follows)
CREATE POLICY "Users can unfollow" ON follows
  FOR DELETE USING (auth.uid() = follower_id);

-- ============================================
-- COMPLETION MESSAGE
-- ============================================
-- If you see this message, the follows table was created successfully!
-- Next steps:
-- 1. Run the Flutter app
-- 2. Test the follow/unfollow functionality

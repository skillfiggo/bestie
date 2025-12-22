-- ============================================
-- BESTIE APP - SUPABASE DATABASE SCHEMA
-- ============================================
-- Execute this SQL in your Supabase SQL Editor
-- Dashboard → SQL Editor → New Query
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- PROFILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  age INTEGER NOT NULL CHECK (age >= 18 AND age <= 100),
  gender TEXT NOT NULL CHECK (gender IN ('male', 'female', 'other')),
  bio TEXT DEFAULT '',
  location TEXT DEFAULT '',
  occupation TEXT DEFAULT '',
  interests TEXT[] DEFAULT '{}',
  avatar_url TEXT DEFAULT '',
  cover_photo_url TEXT DEFAULT '',
  verification_photo_url TEXT DEFAULT '',
  is_verified BOOLEAN DEFAULT FALSE,
  is_online BOOLEAN DEFAULT FALSE,
  coins INTEGER DEFAULT 240,
  diamonds INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- CHATS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS chats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user1_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  user2_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  last_message TEXT DEFAULT '',
  last_message_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user1_id, user2_id)
);

-- ============================================
-- MESSAGES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  message_type TEXT NOT NULL CHECK (message_type IN ('text', 'image', 'voice', 'video')),
  status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sending', 'sent', 'delivered', 'read', 'failed')),
  media_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- CALL HISTORY TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS call_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  caller_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  call_type TEXT NOT NULL CHECK (call_type IN ('incoming', 'outgoing', 'missed')),
  media_type TEXT NOT NULL CHECK (media_type IN ('voice', 'video')),
  duration_seconds INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- VISITORS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS visitors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visitor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  visited_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- FRIENDSHIPS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user1_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  user2_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  friendship_type TEXT DEFAULT 'friend' CHECK (friendship_type IN ('friend', 'bestie')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user1_id, user2_id)
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chats_user1 ON chats(user1_id);
CREATE INDEX IF NOT EXISTS idx_chats_user2 ON chats(user2_id);
CREATE INDEX IF NOT EXISTS idx_profiles_gender ON profiles(gender);
CREATE INDEX IF NOT EXISTS idx_profiles_age ON profiles(age);
CREATE INDEX IF NOT EXISTS idx_profiles_is_online ON profiles(is_online);
CREATE INDEX IF NOT EXISTS idx_call_history_caller ON call_history(caller_id);
CREATE INDEX IF NOT EXISTS idx_call_history_receiver ON call_history(receiver_id);
CREATE INDEX IF NOT EXISTS idx_visitors_visited ON visitors(visited_id);
CREATE INDEX IF NOT EXISTS idx_friendships_user1 ON friendships(user1_id);
CREATE INDEX IF NOT EXISTS idx_friendships_user2 ON friendships(user2_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE call_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE visitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- PROFILES POLICIES
-- Users can view all profiles (for discovery)
CREATE POLICY "Profiles are viewable by everyone" ON profiles
  FOR SELECT USING (true);

-- Users can only update their own profile
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- CHATS POLICIES
-- Users can view chats they are part of
CREATE POLICY "Users can view own chats" ON chats
  FOR SELECT USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- Users can create chats
CREATE POLICY "Users can create chats" ON chats
  FOR INSERT WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

-- Users can update chats they are part of
CREATE POLICY "Users can update own chats" ON chats
  FOR UPDATE USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- MESSAGES POLICIES
-- Users can view messages in their chats
CREATE POLICY "Users can view own messages" ON messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Users can send messages
CREATE POLICY "Users can send messages" ON messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Users can update their own messages (for status updates)
CREATE POLICY "Users can update own messages" ON messages
  FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Users can delete messages they are part of
CREATE POLICY "Users can delete own messages" ON messages
  FOR DELETE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- CALL HISTORY POLICIES
-- Users can view their own call history
CREATE POLICY "Users can view own call history" ON call_history
  FOR SELECT USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

-- Users can insert call records
CREATE POLICY "Users can insert call records" ON call_history
  FOR INSERT WITH CHECK (auth.uid() = caller_id);

-- VISITORS POLICIES
-- Users can view who visited them
CREATE POLICY "Users can view own visitors" ON visitors
  FOR SELECT USING (auth.uid() = visited_id);

-- Users can track their visits
CREATE POLICY "Users can insert visits" ON visitors
  FOR INSERT WITH CHECK (auth.uid() = visitor_id);

-- FRIENDSHIPS POLICIES
-- Users can view their friendships
CREATE POLICY "Users can view own friendships" ON friendships
  FOR SELECT USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- Users can create friendship requests
CREATE POLICY "Users can create friendships" ON friendships
  FOR INSERT WITH CHECK (auth.uid() = user1_id);

-- Users can update friendships they are part of
CREATE POLICY "Users can update own friendships" ON friendships
  FOR UPDATE USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- ============================================
-- FUNCTIONS AND TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for profiles table
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  team_id UUID;
BEGIN
  -- 1. Create Profile
  INSERT INTO public.profiles (id, name, age, gender, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'New User'),
    COALESCE((NEW.raw_user_meta_data->>'age')::INTEGER, 18),
    COALESCE(NEW.raw_user_meta_data->>'gender', 'other'),
    NOW(),
    NOW()
  );

  -- 2. Find Official Team ID (Must be created manually first!)
  SELECT id INTO team_id FROM profiles WHERE name = 'Official Team' LIMIT 1;

  -- 3. If Team exists and is not this user, create a chat
  IF team_id IS NOT NULL AND team_id != NEW.id THEN
    INSERT INTO public.chats (user1_id, user2_id, last_message, last_message_time)
    VALUES (
      NEW.id,
      team_id,
      'Welcome to Bestie! This is the official support channel.',
      NOW()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- ============================================
-- REALTIME SUBSCRIPTIONS
-- ============================================
-- Enable realtime for messages table
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE chats;
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;

-- ============================================
-- STORAGE BUCKETS
-- ============================================
-- 1. Create buckets (if they don't exist)
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('avatars', 'avatars', true),
  ('covers', 'covers', true),
  ('chat-media', 'chat-media', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Enable RLS on objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3. STORAGE POLICIES
-- Allow public access to view files in public buckets
CREATE POLICY "Public Access" ON storage.objects
  FOR SELECT USING ( bucket_id IN ('avatars', 'covers', 'chat-media') );

-- Allow authenticated users to upload files
CREATE POLICY "Auth Upload" ON storage.objects
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND 
    bucket_id IN ('avatars', 'covers', 'chat-media')
  );

-- Allow users to update/delete their own files
CREATE POLICY "Owner Update" ON storage.objects
  FOR UPDATE USING ( auth.uid() = owner ) WITH CHECK ( auth.uid() = owner );

CREATE POLICY "Owner Delete" ON storage.objects
  FOR DELETE USING ( auth.uid() = owner );

-- ============================================
-- COMPLETION MESSAGE
-- ============================================
-- If you see this message, the schema was created successfully!
-- Next steps:
-- 1. Update your .env file with Supabase credentials
-- 2. Run the Flutter app
-- 3. Test authentication and data operations

-- ============================================
-- LOCATION FEATURES
-- ============================================

-- Add location columns to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- Index for location for faster queries
CREATE INDEX IF NOT EXISTS idx_profiles_location ON profiles (latitude, longitude);

-- Function to get nearby profiles
-- Uses the Haversine formula for distance
CREATE OR REPLACE FUNCTION get_nearby_profiles(
  lat DOUBLE PRECISION,
  long DOUBLE PRECISION,
  radius_km DOUBLE PRECISION
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  avatar_url TEXT,
  age INTEGER,
  gender TEXT,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.name,
    p.avatar_url,
    p.age,
    p.gender,
    (
      6371 * acos(
        least(1.0, greatest(-1.0,
          cos(radians(lat)) * cos(radians(p.latitude)) *
          cos(radians(p.longitude) - radians(long)) +
          sin(radians(lat)) * sin(radians(p.latitude))
        ))
      )
    ) AS distance_km
  FROM
    profiles p
  WHERE
    p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    AND p.id != auth.uid() -- Exclude self
    AND (
      6371 * acos(
        least(1.0, greatest(-1.0,
          cos(radians(lat)) * cos(radians(p.latitude)) *
          cos(radians(p.longitude) - radians(long)) +
          sin(radians(lat)) * sin(radians(p.latitude))
        ))
      )
    ) <= radius_km
  ORDER BY
    distance_km ASC;
END;
$$;

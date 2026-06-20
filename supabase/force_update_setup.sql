-- ============================================
-- FORCE UPDATE SYSTEM - DATABASE ENFORCEMENT
-- ============================================
-- This SQL sets up build-number-based version enforcement at the RLS level.
-- Old APKs will receive 403 Forbidden from PostgREST when they try to access tables.

-- ============================================
-- 1. CONFIGURATION: Minimum Build Numbers
-- ============================================

INSERT INTO app_config (key, value)
VALUES 
  ('minimum_app_build', '{"android": 1, "ios": 1}'::jsonb),
  ('force_update_meta', '{
    "android_store_url": "https://play.google.com/store/apps/details?id=com.yourapp",
    "ios_store_url": "https://apps.apple.com/app/idYOURID",
    "message": "Please update to continue using Bestie."
  }'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ============================================
-- 2. HEADER EXTRACTION FUNCTIONS
-- ============================================
-- PostgREST exposes request headers via current_setting('request.headers', true)

-- Extract build number from X-App-Build header
CREATE OR REPLACE FUNCTION public.request_app_build()
RETURNS int
LANGUAGE sql
STABLE
AS $$
  SELECT nullif(
    (current_setting('request.headers', true)::jsonb ->> 'x-app-build'),
    ''
  )::int
$$;

-- Extract platform from X-App-Platform header
CREATE OR REPLACE FUNCTION public.request_platform()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT lower(nullif(
    current_setting('request.headers', true)::jsonb ->> 'x-app-platform',
    ''
  ))
$$;

-- ============================================
-- 3. BUILD VALIDATION FUNCTION
-- ============================================
-- Returns TRUE if the current request's build meets minimum requirements

CREATE OR REPLACE FUNCTION public.is_min_build_ok()
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  cfg jsonb;
  min_build int;
  platform text;
  build int;
BEGIN
  -- Get platform and build from request headers
  platform := public.request_platform();
  build := public.request_app_build();

  -- Strict enforcement: missing headers = blocked
  IF platform IS NULL OR build IS NULL THEN
    RETURN false;
  END IF;

  -- Fetch minimum build config
  SELECT value INTO cfg 
  FROM public.app_config 
  WHERE key = 'minimum_app_build';

  -- Fail open if config is missing (allows access during initial setup)
  IF cfg IS NULL THEN
    RETURN true;
  END IF;

  -- Get minimum build for this platform
  min_build := (cfg ->> platform)::int;

  -- Unknown platform = blocked
  IF min_build IS NULL THEN
    RETURN false;
  END IF;

  -- Check if current build meets minimum
  RETURN build >= min_build;
END;
$$;

-- ============================================
-- 4. UPDATE RLS POLICIES ON CRITICAL TABLES
-- ============================================
-- Add build enforcement to existing policies

-- PROFILES TABLE
-- Update select policy to include build check
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
CREATE POLICY "Profiles are viewable by everyone" ON profiles
  FOR SELECT USING (public.is_min_build_ok());

-- Update insert policy
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id AND public.is_min_build_ok());

-- Update update policy
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id AND public.is_min_build_ok());

-- CHATS TABLE
DROP POLICY IF EXISTS "Users can view own chats" ON chats;
CREATE POLICY "Users can view own chats" ON chats
  FOR SELECT USING (
    (auth.uid() = user1_id OR auth.uid() = user2_id) 
    AND public.is_min_build_ok()
  );

DROP POLICY IF EXISTS "Users can create chats" ON chats;
CREATE POLICY "Users can create chats" ON chats
  FOR INSERT WITH CHECK (
    (auth.uid() = user1_id OR auth.uid() = user2_id)
    AND public.is_min_build_ok()
  );

DROP POLICY IF EXISTS "Users can update own chats" ON chats;
CREATE POLICY "Users can update own chats" ON chats
  FOR UPDATE USING (
    (auth.uid() = user1_id OR auth.uid() = user2_id)
    AND public.is_min_build_ok()
  );

-- MESSAGES TABLE
DROP POLICY IF EXISTS "Users can view own messages" ON messages;
CREATE POLICY "Users can view own messages" ON messages
  FOR SELECT USING (
    (auth.uid() = sender_id OR auth.uid() = receiver_id)
    AND public.is_min_build_ok()
  );

DROP POLICY IF EXISTS "Users can send messages" ON messages;
CREATE POLICY "Users can send messages" ON messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND public.is_min_build_ok()
  );

DROP POLICY IF EXISTS "Users can update own messages" ON messages;
CREATE POLICY "Users can update own messages" ON messages
  FOR UPDATE USING (
    (auth.uid() = sender_id OR auth.uid() = receiver_id)
    AND public.is_min_build_ok()
  );

DROP POLICY IF EXISTS "Users can delete own messages" ON messages;
CREATE POLICY "Users can delete own messages" ON messages
  FOR DELETE USING (
    (auth.uid() = sender_id OR auth.uid() = receiver_id)
    AND public.is_min_build_ok()
  );

-- FRIENDSHIPS TABLE
DROP POLICY IF EXISTS "Users can view own friendships" ON friendships;
CREATE POLICY "Users can view own friendships" ON friendships
  FOR SELECT USING (
    (auth.uid() = user1_id OR auth.uid() = user2_id)
    AND public.is_min_build_ok()
  );

DROP POLICY IF EXISTS "Users can create friendships" ON friendships;
CREATE POLICY "Users can create friendships" ON friendships
  FOR INSERT WITH CHECK (
    auth.uid() = user1_id
    AND public.is_min_build_ok()
  );

DROP POLICY IF EXISTS "Users can update own friendships" ON friendships;
CREATE POLICY "Users can update own friendships" ON friendships
  FOR UPDATE USING (
    (auth.uid() = user1_id OR auth.uid() = user2_id)
    AND public.is_min_build_ok()
  );

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Test the functions (run these manually to verify setup)

-- Check what build/platform the current request has:
-- SELECT public.request_app_build() as build, public.request_platform() as platform;

-- Check if current request would pass:
-- SELECT public.is_min_build_ok() as allowed;

-- View current config:
-- SELECT * FROM app_config WHERE key IN ('minimum_app_build', 'force_update_meta');

-- ============================================
-- USAGE NOTES
-- ============================================
-- To update minimum build requirements:
-- UPDATE app_config 
-- SET value = '{"android": 5, "ios": 5}'::jsonb
-- WHERE key = 'minimum_app_build';
--
-- Old apps (build < 5) will immediately get 403 on all table access.

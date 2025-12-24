-- ============================================
-- FIX BANNER IMAGE URL
-- ============================================

-- Update the app_config with a working image URL
-- Using a reliable placeholder image or a different Unsplash photo
-- This one is a generic 'party/social' vibe image
UPDATE app_config 
SET value = '"https://images.unsplash.com/photo-1529156069898-49953e39b3ac?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80"'::jsonb
WHERE key = 'home_banner_image';

-- Verify the update
SELECT * FROM app_config WHERE key = 'home_banner_image';

-- ================================================================
-- Add avatar_description to ai_profiles
-- This text description of the AI character's physical appearance
-- is used as a prompt guide when generating AI photos, ensuring
-- consistent character appearance across all generated images.
-- ================================================================

ALTER TABLE public.ai_profiles
  ADD COLUMN IF NOT EXISTS avatar_description TEXT NOT NULL DEFAULT '';

COMMENT ON COLUMN public.ai_profiles.avatar_description IS
  'Physical appearance description used as a prompt for AI image generation (hair colour, eye colour, skin tone, face shape, etc.)';

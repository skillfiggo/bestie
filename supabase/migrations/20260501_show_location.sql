-- ============================================================
-- Add show_location column to profiles
-- Controls whether a user's city/region is visible on their profile
-- Defaults to true (visible) to preserve existing behaviour
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS show_location boolean NOT NULL DEFAULT true;

-- Backfill: existing users default to showing location
UPDATE public.profiles SET show_location = true WHERE show_location IS NULL;

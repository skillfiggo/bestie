-- ============================================================
-- Fix get_nearby_profiles: restore all columns needed by
-- ProfileModel, including is_online, show_online_status etc.
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

DROP FUNCTION IF EXISTS get_nearby_profiles(double precision, double precision, double precision, text);

CREATE OR REPLACE FUNCTION get_nearby_profiles(
  lat           DOUBLE PRECISION,
  long          DOUBLE PRECISION,
  radius_km     DOUBLE PRECISION,
  target_gender TEXT DEFAULT NULL
)
RETURNS TABLE (
  id                   UUID,
  bestie_id            TEXT,
  name                 TEXT,
  avatar_url           TEXT,
  age                  INTEGER,
  gender               TEXT,
  bio                  TEXT,
  location             TEXT,
  occupation           TEXT,
  interests            TEXT[],
  cover_photo_url      TEXT,
  verification_photo_url TEXT,
  is_verified          BOOLEAN,
  is_online            BOOLEAN,
  show_online_status   BOOLEAN,
  show_last_seen       BOOLEAN,
  last_active_at       TIMESTAMPTZ,
  coins                INTEGER,
  diamonds             INTEGER,
  free_messages_count  INTEGER,
  gallery_urls         TEXT[],
  role                 TEXT,
  status               TEXT,
  latitude             DOUBLE PRECISION,
  longitude            DOUBLE PRECISION,
  distance_km          DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.bestie_id,
    p.name,
    p.avatar_url,
    p.age,
    p.gender,
    p.bio,
    p.location,
    p.occupation,
    p.interests,
    p.cover_photo_url,
    p.verification_photo_url,
    p.is_verified,
    p.is_online,
    COALESCE(p.show_online_status, true)   AS show_online_status,
    COALESCE(p.show_last_seen, true)       AS show_last_seen,
    p.last_active_at,
    COALESCE(p.coins, 0)                   AS coins,
    COALESCE(p.diamonds, 0)               AS diamonds,
    COALESCE(p.free_messages_count, 0)    AS free_messages_count,
    COALESCE(p.gallery_urls, '{}'::text[]) AS gallery_urls,
    COALESCE(p.role, 'user')              AS role,
    COALESCE(p.status, 'active')          AS status,
    p.latitude,
    p.longitude,
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
    p.latitude  IS NOT NULL
    AND p.longitude IS NOT NULL
    AND p.status    != 'banned'
    AND p.id        != auth.uid()                                      -- exclude self
    AND (target_gender IS NULL OR p.gender = target_gender)
    AND (p.gender != 'female' OR p.is_verified = true)                 -- female must be verified
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

DO $$
BEGIN
  RAISE NOTICE '✅ get_nearby_profiles updated — now returns is_online, show_online_status and all ProfileModel fields';
END $$;

-- 1. Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Add geography column to profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS location_geog GEOGRAPHY(POINT, 4326);

-- 3. Migrate existing latitude and longitude data
UPDATE profiles
SET location_geog = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- 4. Create GIST index for fast spatial queries
CREATE INDEX IF NOT EXISTS profiles_location_geog_idx ON profiles USING GIST (location_geog);

-- 5. Update get_nearby_profiles to use PostGIS
CREATE OR REPLACE FUNCTION get_nearby_profiles(
  lat DOUBLE PRECISION,
  long DOUBLE PRECISION,
  radius_km DOUBLE PRECISION,
  target_gender TEXT DEFAULT NULL
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
    ST_Distance(
      p.location_geog,
      ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography
    ) / 1000 AS distance_km
  FROM
    profiles p
  WHERE
    p.location_geog IS NOT NULL
    AND (target_gender IS NULL OR p.gender = target_gender)
    AND (p.gender != 'female' OR p.is_verified = true)
    AND ST_DWithin(
      p.location_geog,
      ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography,
      radius_km * 1000
    )
  ORDER BY
    distance_km ASC;
END;
$$;

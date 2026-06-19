-- ============================================================
-- Party Time: YouTube DJ Rooms + Gifting System
-- Migration: party_rooms_schema
-- ============================================================

-- Active party rooms
CREATE TABLE IF NOT EXISTS party_rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  current_video_id text,
  current_video_title text,
  current_video_thumbnail text,
  is_playing boolean DEFAULT false,
  position_ms bigint DEFAULT 0,
  dj_user_id uuid REFERENCES profiles(id),
  is_active boolean DEFAULT true,
  member_count int DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Shared music queue
CREATE TABLE IF NOT EXISTS party_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES party_rooms(id) ON DELETE CASCADE,
  added_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  video_id text NOT NULL,
  video_title text NOT NULL,
  video_thumbnail text NOT NULL,
  duration_seconds int DEFAULT 0,
  position int NOT NULL DEFAULT 0,
  played boolean DEFAULT false,
  added_at timestamptz DEFAULT now()
);

-- Room members (presence tracking)
CREATE TABLE IF NOT EXISTS party_room_members (
  room_id uuid REFERENCES party_rooms(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  user_name text NOT NULL DEFAULT '',
  user_avatar text NOT NULL DEFAULT '',
  joined_at timestamptz DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);

-- Gift event log
CREATE TABLE IF NOT EXISTS party_gifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES party_rooms(id) ON DELETE CASCADE,
  sender_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  receiver_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  gift_type text NOT NULL,
  gift_emoji text NOT NULL,
  gift_label text NOT NULL,
  coin_cost int NOT NULL,
  diamond_earn int NOT NULL,    -- 30% of coin_cost goes to DJ as diamonds
  sent_at timestamptz DEFAULT now()
);

-- ── RLS Policies ────────────────────────────────────────────

ALTER TABLE party_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE party_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE party_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE party_gifts ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users full access
CREATE POLICY "party_rooms_authenticated" ON party_rooms
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "party_queue_authenticated" ON party_queue
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "party_members_authenticated" ON party_room_members
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "party_gifts_authenticated" ON party_gifts
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ── Indexes ──────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_party_rooms_active ON party_rooms(is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_party_queue_room ON party_queue(room_id, position ASC, played ASC);
CREATE INDEX IF NOT EXISTS idx_party_members_room ON party_room_members(room_id);
CREATE INDEX IF NOT EXISTS idx_party_gifts_room ON party_gifts(room_id, sent_at DESC);

-- ── Realtime ─────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE party_rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE party_room_members;

-- ── Helper function: atomic gift transfer ────────────────────
-- DJ earns 30% of coin cost as diamonds; platform keeps 70%
CREATE OR REPLACE FUNCTION send_party_gift(
  p_room_id uuid,
  p_sender_id uuid,
  p_receiver_id uuid,
  p_gift_type text,
  p_gift_emoji text,
  p_gift_label text,
  p_coin_cost int,
  p_diamond_earn int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. Deduct coins from sender
  UPDATE profiles
  SET coins = coins - p_coin_cost
  WHERE id = p_sender_id AND coins >= p_coin_cost;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient coins';
  END IF;

  -- 2. Award diamonds to DJ (30% as diamonds)
  UPDATE profiles
  SET diamonds = diamonds + p_diamond_earn
  WHERE id = p_receiver_id;

  -- 3. Log the gift
  INSERT INTO party_gifts (
    room_id, sender_id, receiver_id,
    gift_type, gift_emoji, gift_label,
    coin_cost, diamond_earn
  ) VALUES (
    p_room_id, p_sender_id, p_receiver_id,
    p_gift_type, p_gift_emoji, p_gift_label,
    p_coin_cost, p_diamond_earn
  );
END;
$$;

-- Helper: safely increment member count
CREATE OR REPLACE FUNCTION increment_party_members(p_room_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE party_rooms SET member_count = GREATEST(member_count + 1, 1) WHERE id = p_room_id;
END;
$$;

-- Helper: safely decrement member count (floor 0)
CREATE OR REPLACE FUNCTION decrement_party_members(p_room_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE party_rooms SET member_count = GREATEST(member_count - 1, 0) WHERE id = p_room_id;
END;
$$;

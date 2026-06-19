-- ============================================================
-- After Dark — Database Migration
-- Created: 2026-06-16
-- Replaces: party_rooms / party feature
-- ============================================================

-- 1. Daily topics
CREATE TABLE IF NOT EXISTS after_dark_topics (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic       text NOT NULL,
  reveal_date date NOT NULL UNIQUE,
  created_at  timestamptz DEFAULT now()
);

-- 2. User stories (one per user per topic/day)
CREATE TABLE IF NOT EXISTS after_dark_stories (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  topic_id         uuid REFERENCES after_dark_topics(id) ON DELETE CASCADE NOT NULL,
  content          text NOT NULL CHECK (char_length(content) BETWEEN 50 AND 1000),
  is_anonymous     boolean NOT NULL DEFAULT false,
  status           text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  total_diamonds   integer NOT NULL DEFAULT 0,
  like_count       integer NOT NULL DEFAULT 0,
  super_like_count integer NOT NULL DEFAULT 0,
  created_at       timestamptz DEFAULT now(),
  UNIQUE (user_id, topic_id)
);

-- 3. Reactions (free like OR paid super_like — one per type per user per story)
CREATE TABLE IF NOT EXISTS after_dark_reactions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id   uuid REFERENCES after_dark_stories(id) ON DELETE CASCADE NOT NULL,
  user_id    uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type       text NOT NULL CHECK (type IN ('like', 'super_like')),
  created_at timestamptz DEFAULT now(),
  UNIQUE (story_id, user_id, type)
);

-- 4. Story gifts (super_comment 50🪙 / story_gift_100 / story_gift_200)
CREATE TABLE IF NOT EXISTS after_dark_gifts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id   uuid REFERENCES after_dark_stories(id) ON DELETE CASCADE NOT NULL,
  sender_id  uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  gift_type  text NOT NULL,
  coin_cost  integer NOT NULL,
  message    text,
  created_at timestamptz DEFAULT now()
);

-- 5. Anonymous compliments (10 coins, sender identity never revealed)
CREATE TABLE IF NOT EXISTS after_dark_compliments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id   uuid REFERENCES after_dark_stories(id) ON DELETE CASCADE NOT NULL,
  sender_id  uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  message    text NOT NULL CHECK (char_length(message) BETWEEN 1 AND 200),
  coin_cost  integer NOT NULL DEFAULT 10,
  created_at timestamptz DEFAULT now()
);

-- ── Indexes ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_after_dark_stories_topic    ON after_dark_stories(topic_id);
CREATE INDEX IF NOT EXISTS idx_after_dark_stories_user     ON after_dark_stories(user_id);
CREATE INDEX IF NOT EXISTS idx_after_dark_stories_status   ON after_dark_stories(status);
CREATE INDEX IF NOT EXISTS idx_after_dark_reactions_story  ON after_dark_reactions(story_id);
CREATE INDEX IF NOT EXISTS idx_after_dark_gifts_story      ON after_dark_gifts(story_id);
CREATE INDEX IF NOT EXISTS idx_after_dark_compliments_story ON after_dark_compliments(story_id);

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE after_dark_topics      ENABLE ROW LEVEL SECURITY;
ALTER TABLE after_dark_stories     ENABLE ROW LEVEL SECURITY;
ALTER TABLE after_dark_reactions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE after_dark_gifts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE after_dark_compliments ENABLE ROW LEVEL SECURITY;

-- Topics: public read, admin insert
CREATE POLICY "topics_read_all"   ON after_dark_topics FOR SELECT USING (true);

-- Stories: approved stories visible to all; owner can insert/update; admin can update status
CREATE POLICY "stories_read_approved" ON after_dark_stories
  FOR SELECT USING (status = 'approved' OR auth.uid() = user_id);

CREATE POLICY "stories_insert_own" ON after_dark_stories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "stories_update_own" ON after_dark_stories
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "stories_select_admin" ON after_dark_stories
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "stories_update_admin" ON after_dark_stories
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "stories_delete_admin" ON after_dark_stories
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Reactions: auth users can read/insert/delete own
CREATE POLICY "reactions_read"   ON after_dark_reactions FOR SELECT USING (true);
CREATE POLICY "reactions_insert" ON after_dark_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "reactions_delete" ON after_dark_reactions FOR DELETE USING (auth.uid() = user_id);

-- Gifts: auth users can insert and read
CREATE POLICY "gifts_read"   ON after_dark_gifts FOR SELECT USING (true);
CREATE POLICY "gifts_insert" ON after_dark_gifts FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Compliments: sender sees own, story owner sees received (no sender info exposed to owner)
CREATE POLICY "compliments_sender_read" ON after_dark_compliments
  FOR SELECT USING (auth.uid() = sender_id);
CREATE POLICY "compliments_insert" ON after_dark_compliments
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- ── Stored procedure: award_after_dark_diamonds ───────────────
-- Awards 60% of coin_cost as diamonds to story author.
-- Called by edge function (service role bypasses RLS).
CREATE OR REPLACE FUNCTION award_after_dark_diamonds(
  p_story_id  uuid,
  p_diamonds  integer
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE after_dark_stories
    SET total_diamonds = total_diamonds + p_diamonds
    WHERE id = p_story_id;

  UPDATE profiles
    SET diamonds = diamonds + p_diamonds
    WHERE id = (SELECT user_id FROM after_dark_stories WHERE id = p_story_id);
END;
$$;

-- ── Stored procedure: increment_story_likes ───────────────────
CREATE OR REPLACE FUNCTION increment_story_likes(
  p_story_id uuid,
  p_type     text  -- 'like' or 'super_like'
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_type = 'like' THEN
    UPDATE after_dark_stories SET like_count = like_count + 1 WHERE id = p_story_id;
  ELSIF p_type = 'super_like' THEN
    UPDATE after_dark_stories SET super_like_count = super_like_count + 1 WHERE id = p_story_id;
  END IF;
END;
$$;

-- ── Weekly leaderboard view ────────────────────────────────────
CREATE OR REPLACE VIEW after_dark_leaderboard AS
SELECT
  s.id              AS story_id,
  s.user_id,
  s.is_anonymous,
  s.content,
  s.total_diamonds,
  s.like_count,
  s.super_like_count,
  p.name        AS username,
  p.avatar_url,
  t.topic,
  t.reveal_date
FROM after_dark_stories s
JOIN profiles p ON p.id = s.user_id
JOIN after_dark_topics t ON t.id = s.topic_id
WHERE
  s.status = 'approved'
  AND t.reveal_date >= (CURRENT_DATE - INTERVAL '7 days')
ORDER BY s.total_diamonds DESC, s.super_like_count DESC, s.like_count DESC
LIMIT 50;

-- ── Seed: 14 days of topics ────────────────────────────────────
INSERT INTO after_dark_topics (topic, reveal_date) VALUES
  ('What is the most daring thing you have done for love?',             CURRENT_DATE),
  ('Describe a moment when someone made your heart race unexpectedly.', CURRENT_DATE + 1),
  ('Confess a flirty secret you have never told anyone.',               CURRENT_DATE + 2),
  ('Tell the story of your most unforgettable night out.',              CURRENT_DATE + 3),
  ('What would you do if you had one completely free night?',           CURRENT_DATE + 4),
  ('Describe your perfect mysterious stranger encounter.',              CURRENT_DATE + 5),
  ('Write the opening line of your most scandalous memory.',            CURRENT_DATE + 6),
  ('The text you wished you had the courage to send.',                  CURRENT_DATE + 7),
  ('Describe the moment you knew you were attracted to someone.',       CURRENT_DATE + 8),
  ('What is the boldest thing you have ever said to someone you liked?',CURRENT_DATE + 9),
  ('Describe a time you stayed up all night for the right reasons.',    CURRENT_DATE + 10),
  ('Write about the one that got away — in exactly 200 words.',         CURRENT_DATE + 11),
  ('What secret does your closest friend not know about you?',          CURRENT_DATE + 12),
  ('Describe your most embarrassing romantic moment.',                  CURRENT_DATE + 13)
ON CONFLICT (reveal_date) DO NOTHING;

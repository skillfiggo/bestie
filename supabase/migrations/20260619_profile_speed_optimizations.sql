-- ─────────────────────────────────────────────────────────────
-- Indexes for fast COUNT queries on follows & friendships
-- ─────────────────────────────────────────────────────────────

-- follows: looking up followers of a user (following_id = X)
CREATE INDEX IF NOT EXISTS idx_follows_following_id
  ON public.follows(following_id);

-- follows: looking up who a user follows (follower_id = X)
CREATE INDEX IF NOT EXISTS idx_follows_follower_id
  ON public.follows(follower_id);

-- friendships: looking up by user1_id
CREATE INDEX IF NOT EXISTS idx_friendships_user1_id
  ON public.friendships(user1_id);

-- friendships: looking up by user2_id
CREATE INDEX IF NOT EXISTS idx_friendships_user2_id
  ON public.friendships(user2_id);

-- ─────────────────────────────────────────────────────────────
-- RPC: return all social stats for a user in one round-trip
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_user_stats(user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE         -- result is stable within a transaction (allows caching)
SECURITY DEFINER
AS $$
DECLARE
  follower_cnt  INT;
  following_cnt INT;
  friend_cnt    INT;
  bestie_cnt    INT;
BEGIN
  SELECT COUNT(*)::INT INTO follower_cnt
  FROM public.follows
  WHERE following_id = user_id;

  SELECT COUNT(*)::INT INTO following_cnt
  FROM public.follows
  WHERE follower_id = user_id;

  SELECT COUNT(*)::INT INTO friend_cnt
  FROM public.friendships
  WHERE status = 'accepted'
    AND friendship_type = 'friend'
    AND (user1_id = user_id OR user2_id = user_id);

  SELECT COUNT(*)::INT INTO bestie_cnt
  FROM public.friendships
  WHERE status = 'accepted'
    AND friendship_type = 'bestie'
    AND (user1_id = user_id OR user2_id = user_id);

  RETURN jsonb_build_object(
    'follower_count',  follower_cnt,
    'following_count', following_cnt,
    'friends_count',   friend_cnt,
    'besties_count',   bestie_cnt
  );
END;
$$;

-- ============================================================
-- blocked_users table
-- Tracks which users have been blocked by which users.
-- blocker_id: the user who initiated the block
-- blocked_id: the user who was blocked
-- ============================================================

CREATE TABLE IF NOT EXISTS public.blocked_users (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),

  -- Prevent duplicate blocks
  CONSTRAINT blocked_users_unique UNIQUE (blocker_id, blocked_id),
  -- Prevent self-blocking
  CONSTRAINT blocked_users_no_self_block CHECK (blocker_id <> blocked_id)
);

-- Index for fast lookups in both directions
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON public.blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked ON public.blocked_users(blocked_id);

-- ============================================================
-- Row Level Security
-- ============================================================

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- Users can see their own block list (rows where they are the blocker)
CREATE POLICY "Users can view their own block list"
  ON public.blocked_users
  FOR SELECT
  USING (auth.uid() = blocker_id);

-- Users can block other users (insert their own blocker_id)
CREATE POLICY "Users can block other users"
  ON public.blocked_users
  FOR INSERT
  WITH CHECK (auth.uid() = blocker_id);

-- Users can unblock (delete their own block records)
CREATE POLICY "Users can unblock users"
  ON public.blocked_users
  FOR DELETE
  USING (auth.uid() = blocker_id);

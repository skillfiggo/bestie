-- =================================================================
-- Voice Match Queue: Efficiency Improvements (idempotent / safe to re-run)
-- =================================================================

-- 1. Add preferred_gender column (safe — skips if already exists)
ALTER TABLE public.voice_match_queue
  ADD COLUMN IF NOT EXISTS preferred_gender TEXT DEFAULT 'any';

-- 2. Enable RLS (safe — no-op if already enabled)
ALTER TABLE public.voice_match_queue ENABLE ROW LEVEL SECURITY;

-- 3. Create policy only if it doesn't already exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'voice_match_queue'
      AND policyname = 'Users manage own queue entry'
  ) THEN
    EXECUTE 'CREATE POLICY "Users manage own queue entry" ON public.voice_match_queue
      FOR ALL USING (auth.uid() = user_id)';
  END IF;
END;
$$;

-- 4. Enable Realtime only if not already a member
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'voice_match_queue'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.voice_match_queue';
  END IF;
END;
$$;

-- 5. Add a partial index for fast queue lookup (safe — skips if already exists)
CREATE INDEX IF NOT EXISTS idx_voice_match_queue_active
  ON public.voice_match_queue (status, preferred_gender, created_at)
  WHERE status = 'matching';

-- 3. Update join_voice_match_queue with gender-aware matching + stale heartbeat
CREATE OR REPLACE FUNCTION public.join_voice_match_queue(
  p_user_id        UUID,
  p_user_gender    TEXT DEFAULT 'any'   -- caller passes their own gender
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_other_user_id   UUID;
  v_channel_id      TEXT;
  v_result          JSON;
  v_opposite_gender TEXT;
BEGIN
  -- 1. Remove any stale entry for this user
  DELETE FROM public.voice_match_queue WHERE user_id = p_user_id;

  -- 2. Determine opposite gender for preferred matching
  v_opposite_gender := CASE
    WHEN p_user_gender = 'male'   THEN 'female'
    WHEN p_user_gender = 'female' THEN 'male'
    ELSE 'any'
  END;

  -- 3a. Try to find someone of the opposite gender first (preferred cross-gender match)
  IF v_opposite_gender != 'any' THEN
    SELECT user_id INTO v_other_user_id
    FROM public.voice_match_queue
    WHERE status = 'matching'
      AND user_id != p_user_id
      AND preferred_gender = p_user_gender  -- they want us
      -- Not stale (heartbeat must be within 20 seconds)
      AND updated_at > NOW() - INTERVAL '20 seconds'
    ORDER BY created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;
  END IF;

  -- 3b. Fallback: find anyone waiting (any gender)
  IF v_other_user_id IS NULL THEN
    SELECT user_id INTO v_other_user_id
    FROM public.voice_match_queue
    WHERE status = 'matching'
      AND user_id != p_user_id
      AND updated_at > NOW() - INTERVAL '20 seconds'
    ORDER BY created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;
  END IF;

  IF v_other_user_id IS NOT NULL THEN
    -- 4a. Matched — generate shared Agora channel ID
    v_channel_id := 'vm_' || REPLACE(gen_random_uuid()::TEXT, '-', '');

    -- Update the waiting user to matched
    UPDATE public.voice_match_queue
    SET status          = 'matched',
        matched_user_id = p_user_id,
        channel_id      = v_channel_id,
        updated_at      = NOW()
    WHERE user_id = v_other_user_id;

    -- Insert the current user as matched
    INSERT INTO public.voice_match_queue (user_id, status, matched_user_id, channel_id, preferred_gender)
    VALUES (p_user_id, 'matched', v_other_user_id, v_channel_id, v_opposite_gender);

    v_result := json_build_object(
      'status',          'matched',
      'matched_user_id', v_other_user_id::TEXT,
      'channel_id',      v_channel_id,
      'is_initiator',    true
    );
  ELSE
    -- 4b. No match — join queue and wait
    INSERT INTO public.voice_match_queue (user_id, status, preferred_gender)
    VALUES (p_user_id, 'matching', v_opposite_gender);

    v_result := json_build_object(
      'status',          'matching',
      'matched_user_id', NULL,
      'channel_id',      NULL,
      'is_initiator',    false
    );
  END IF;

  RETURN v_result;
END;
$$;

-- 4. Heartbeat RPC — Flutter calls this every 10 seconds while waiting
--    Bumps updated_at so the entry isn't treated as stale by other searchers
CREATE OR REPLACE FUNCTION public.ping_voice_match_queue(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.voice_match_queue
  SET updated_at = NOW()
  WHERE user_id = p_user_id
    AND status = 'matching';
END;
$$;

-- =================================================================
-- Voice Match Queue: Random Matchmaking for Voice Calls
-- =================================================================

-- 1. Create the matchmaking queue table
CREATE TABLE IF NOT EXISTS public.voice_match_queue (
  user_id         UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  status          TEXT NOT NULL DEFAULT 'matching' CHECK (status IN ('matching', 'matched')),
  matched_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  channel_id      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.voice_match_queue ENABLE ROW LEVEL SECURITY;

-- Users can see/manage only their own queue entry
CREATE POLICY "Users manage own queue entry" ON public.voice_match_queue
  FOR ALL USING (auth.uid() = user_id);

-- 2. Enable Realtime on the table so clients can subscribe
ALTER PUBLICATION supabase_realtime ADD TABLE public.voice_match_queue;

-- 3. join_voice_match_queue RPC
-- Returns:
--   status: 'matched' | 'matching'
--   matched_user_id: UUID | null
--   channel_id: text | null
CREATE OR REPLACE FUNCTION public.join_voice_match_queue(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_other_user_id  UUID;
  v_channel_id     TEXT;
  v_result         JSON;
BEGIN
  -- 1. Remove any stale entry for this user (e.g. left without cancelling)
  DELETE FROM public.voice_match_queue WHERE user_id = p_user_id;

  -- 2. Try to find another user waiting (use FOR UPDATE SKIP LOCKED to prevent race conditions)
  SELECT user_id INTO v_other_user_id
  FROM public.voice_match_queue
  WHERE status = 'matching'
    AND user_id != p_user_id
    -- Ignore stale entries older than 30 seconds
    AND created_at > NOW() - INTERVAL '30 seconds'
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_other_user_id IS NOT NULL THEN
    -- 3a. Found a match — generate a shared channel ID
    v_channel_id := 'vm_' || REPLACE(gen_random_uuid()::TEXT, '-', '');

    -- Update the waiting user to matched
    UPDATE public.voice_match_queue
    SET status = 'matched',
        matched_user_id = p_user_id,
        channel_id = v_channel_id,
        updated_at = NOW()
    WHERE user_id = v_other_user_id;

    -- Insert the current user as matched
    INSERT INTO public.voice_match_queue (user_id, status, matched_user_id, channel_id)
    VALUES (p_user_id, 'matched', v_other_user_id, v_channel_id);

    v_result := json_build_object(
      'status', 'matched',
      'matched_user_id', v_other_user_id::TEXT,
      'channel_id', v_channel_id,
      'is_initiator', true
    );
  ELSE
    -- 3b. No match found — add to queue and wait
    INSERT INTO public.voice_match_queue (user_id, status)
    VALUES (p_user_id, 'matching');

    v_result := json_build_object(
      'status', 'matching',
      'matched_user_id', NULL,
      'channel_id', NULL,
      'is_initiator', false
    );
  END IF;

  RETURN v_result;
END;
$$;

-- 4. leave_voice_match_queue RPC — call when user cancels or closes the screen
CREATE OR REPLACE FUNCTION public.leave_voice_match_queue(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.voice_match_queue WHERE user_id = p_user_id;
END;
$$;

-- 5. Cleanup stale queue entries older than 2 minutes (optional job trigger if pg_cron is available)
-- This is a safety net in case users disconnect without calling leave_voice_match_queue
CREATE OR REPLACE FUNCTION public.cleanup_stale_voice_match_queue()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.voice_match_queue
  WHERE status = 'matching'
    AND created_at < NOW() - INTERVAL '2 minutes';
END;
$$;

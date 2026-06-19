-- ============================================================
-- RATE LIMITING
-- Provides per-user, per-action rate limiting entirely in SQL.
-- Works on the Supabase Free plan (no dashboard controls needed).
-- ============================================================

-- Table to track per-user action counts within a time window
CREATE TABLE IF NOT EXISTS public.api_rate_limits (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action      text NOT NULL,           -- e.g. 'init_payment', 'agora_token', 'withdrawal'
  window_start timestamptz NOT NULL,   -- start of the current window
  call_count  integer NOT NULL DEFAULT 1,
  updated_at  timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT api_rate_limits_unique UNIQUE (user_id, action, window_start)
);

-- Index for fast per-user lookups
CREATE INDEX IF NOT EXISTS idx_rate_limits_user_action
  ON public.api_rate_limits (user_id, action, window_start DESC);

-- RLS: users cannot see or touch this table directly
ALTER TABLE public.api_rate_limits ENABLE ROW LEVEL SECURITY;
-- No user-facing policies — only accessed by SECURITY DEFINER functions

-- ============================================================
-- FUNCTION: check_rate_limit
-- Call this at the start of any sensitive RPC.
-- Raises an exception (HTTP 429) if the user is over the limit.
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id       uuid,
  p_action        text,
  p_max_calls     integer,        -- e.g. 10
  p_window_secs   integer         -- e.g. 3600 for 1 hour
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_window_start  timestamptz;
  v_count         integer;
BEGIN
  -- Round down to the nearest window boundary
  v_window_start := date_trunc('second', now()) -
                    (EXTRACT(EPOCH FROM now())::integer % p_window_secs || ' seconds')::interval;

  -- Upsert: increment call count for this user/action/window
  INSERT INTO public.api_rate_limits (user_id, action, window_start, call_count)
  VALUES (p_user_id, p_action, v_window_start, 1)
  ON CONFLICT (user_id, action, window_start)
  DO UPDATE SET
    call_count = api_rate_limits.call_count + 1,
    updated_at = now()
  RETURNING call_count INTO v_count;

  -- Enforce the limit
  IF v_count > p_max_calls THEN
    RAISE EXCEPTION 'Rate limit exceeded for action %. Try again later. (code: 429)', p_action
      USING HINT = 'rate_limit_exceeded';
  END IF;
END;
$$;

-- ============================================================
-- FUNCTION: cleanup_old_rate_limit_windows
-- Run periodically (e.g. daily via pg_cron on Pro, or manually).
-- Removes entries older than 24 hours to keep the table small.
-- ============================================================
CREATE OR REPLACE FUNCTION public.cleanup_old_rate_limit_windows()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.api_rate_limits
  WHERE window_start < now() - interval '24 hours';

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

-- ============================================================
-- Apply rate limits inside process_successful_payment
-- This wraps the existing function with a rate limit guard.
-- Limit: 20 payment attempts per hour per user.
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_successful_payment(
  p_user_id   uuid,
  p_reference text,
  p_amount    numeric,
  p_coins     int,
  p_provider  text
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_balance int;
BEGIN
  -- Rate limit: max 20 payment processing calls per hour
  PERFORM public.check_rate_limit(p_user_id, 'process_payment', 20, 3600);

  -- Insert into history (unique reference prevents double-credit)
  INSERT INTO payment_history (user_id, reference, provider, amount, coins_added)
  VALUES (p_user_id, p_reference, p_provider, p_amount, p_coins);

  -- Update coin balance atomically
  UPDATE profiles
  SET coins = coins + p_coins
  WHERE id = p_user_id
  RETURNING coins INTO v_new_balance;

  RETURN v_new_balance;
END;
$$;

-- ============================================================
-- Apply rate limits to withdrawal requests
-- Max 5 withdrawal requests per 24 hours per user.
-- ============================================================
-- This is enforced via the check_rate_limit function called
-- from the approve-withdrawal edge function (see edge function patch).

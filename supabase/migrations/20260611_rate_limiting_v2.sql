-- ============================================================
-- RATE LIMITING v2
-- Replaces 20260501_rate_limiting.sql with fixes for:
--   • Off-by-one: count BEFORE incrementing so the limit is exact
--   • Window alignment: use integer division, not modulo on epoch
--   • process_successful_payment: proper ON CONFLICT idempotency
--   • Withdrawal rate limiting: wired up (was only a comment before)
--   • Cleanup: respects a configurable max-window argument
--   • pg_cron: scheduled daily cleanup if the extension is present
-- Run this AFTER 20260501_rate_limiting.sql (it uses CREATE OR REPLACE).
-- ============================================================

-- ============================================================
-- 1. Ensure the table exists (idempotent if already created)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.api_rate_limits (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action       text        NOT NULL,
  window_start timestamptz NOT NULL,
  call_count   integer     NOT NULL DEFAULT 1,
  updated_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT api_rate_limits_unique UNIQUE (user_id, action, window_start)
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_user_action
  ON public.api_rate_limits (user_id, action, window_start DESC);

ALTER TABLE public.api_rate_limits ENABLE ROW LEVEL SECURITY;
-- No user policies — only reachable via SECURITY DEFINER functions.

-- ============================================================
-- 2. FUNCTION: check_rate_limit  (fixed)
--
-- Strategy: READ current count first, THEN increment.
-- This means:
--   • At limit  → reject before writing (no wasted increment)
--   • Under limit → increment atomically
--   • Concurrent requests handled by the UNIQUE constraint upsert
--
-- Window alignment: floor(epoch / window_secs) * window_secs
-- This gives a stable, repeatable boundary for any window size.
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id     uuid,
  p_action      text,
  p_max_calls   integer,   -- e.g. 10
  p_window_secs integer    -- e.g. 3600
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_window_start  timestamptz;
  v_current_count integer;
BEGIN
  -- Align window to a fixed boundary: floor(epoch / window) * window
  v_window_start := to_timestamp(
    (floor(extract(epoch from now()) / p_window_secs) * p_window_secs)::bigint
  );

  -- Read the current count BEFORE incrementing
  SELECT call_count INTO v_current_count
  FROM public.api_rate_limits
  WHERE user_id     = p_user_id
    AND action      = p_action
    AND window_start = v_window_start;

  -- Reject early — don't waste a write if already at the limit
  IF FOUND AND v_current_count >= p_max_calls THEN
    RAISE EXCEPTION 'Rate limit exceeded for action "%". Retry after the current window expires. (code: 429)', p_action
      USING HINT = 'rate_limit_exceeded';
  END IF;

  -- Upsert: safe for concurrent callers thanks to the UNIQUE constraint
  INSERT INTO public.api_rate_limits (user_id, action, window_start, call_count)
  VALUES (p_user_id, p_action, v_window_start, 1)
  ON CONFLICT (user_id, action, window_start)
  DO UPDATE SET
    call_count = api_rate_limits.call_count + 1,
    updated_at = now();
END;
$$;

-- ============================================================
-- 3. FUNCTION: get_rate_limit_status
-- Returns remaining calls and seconds until window reset.
-- Useful for exposing X-RateLimit-* style info to clients.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_rate_limit_status(
  p_user_id     uuid,
  p_action      text,
  p_max_calls   integer,
  p_window_secs integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_window_start  timestamptz;
  v_window_end    timestamptz;
  v_count         integer := 0;
BEGIN
  v_window_start := to_timestamp(
    (floor(extract(epoch from now()) / p_window_secs) * p_window_secs)::bigint
  );
  v_window_end := v_window_start + (p_window_secs || ' seconds')::interval;

  SELECT COALESCE(call_count, 0) INTO v_count
  FROM public.api_rate_limits
  WHERE user_id     = p_user_id
    AND action      = p_action
    AND window_start = v_window_start;

  RETURN jsonb_build_object(
    'action',         p_action,
    'limit',          p_max_calls,
    'remaining',      GREATEST(0, p_max_calls - v_count),
    'used',           v_count,
    'window_reset_at', v_window_end,
    'retry_after_secs', GREATEST(0, extract(epoch from (v_window_end - now()))::int)
  );
END;
$$;

-- ============================================================
-- 4. FUNCTION: reset_rate_limit  (admin utility)
-- Clears all rate limit windows for a given user+action.
-- ============================================================
CREATE OR REPLACE FUNCTION public.reset_rate_limit(
  p_user_id uuid,
  p_action  text DEFAULT NULL  -- NULL = reset all actions for the user
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_is_admin boolean;
  v_deleted  integer;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin
  FROM public.profiles WHERE id = v_admin_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Only admins can reset rate limits';
  END IF;

  DELETE FROM public.api_rate_limits
  WHERE user_id = p_user_id
    AND (p_action IS NULL OR action = p_action);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

-- ============================================================
-- 5. FUNCTION: cleanup_old_rate_limit_windows  (improved)
-- Deletes rows older than the largest possible window in use.
-- Default: 48 hours (covers the 1-hour and 24-hour windows with margin).
-- ============================================================
CREATE OR REPLACE FUNCTION public.cleanup_old_rate_limit_windows(
  p_max_window_hours integer DEFAULT 48
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.api_rate_limits
  WHERE window_start < now() - (p_max_window_hours || ' hours')::interval;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

-- ============================================================
-- 6. FUNCTION: process_successful_payment  (idempotency fix)
-- Added ON CONFLICT DO NOTHING on the reference unique key so
-- duplicate reference replays return the current balance silently
-- instead of crashing with an unhandled exception.
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
  v_inserted    boolean;
BEGIN
  -- Rate limit: max 20 payment processing attempts per hour
  PERFORM public.check_rate_limit(p_user_id, 'process_payment', 20, 3600);

  -- Insert into history; silently ignore duplicate references (idempotency)
  INSERT INTO payment_history (user_id, reference, provider, amount, coins_added)
  VALUES (p_user_id, p_reference, p_provider, p_amount, p_coins)
  ON CONFLICT (reference) DO NOTHING;

  -- FOUND is true only if the INSERT wrote a row
  v_inserted := FOUND;

  -- Only update coins if this is a new reference
  IF v_inserted THEN
    UPDATE profiles
    SET coins = coins + p_coins
    WHERE id = p_user_id
    RETURNING coins INTO v_new_balance;
  ELSE
    -- Already processed — return current balance without re-crediting
    SELECT coins INTO v_new_balance FROM profiles WHERE id = p_user_id;
  END IF;

  RETURN v_new_balance;
END;
$$;

-- ============================================================
-- 7. FUNCTION: request_withdrawal  (wired rate limit)
-- Rate limit: max 5 withdrawal requests per 24 hours.
-- Creates a pending request and deducts diamonds immediately.
-- ============================================================
CREATE OR REPLACE FUNCTION public.request_withdrawal(
  p_amount_diamonds integer,
  p_amount_naira    numeric,
  p_account_name    text,
  p_account_number  text,
  p_bank_code       text,
  p_bank_name       text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id       uuid := auth.uid();
  v_balance       integer;
  v_request_id    uuid;
BEGIN
  -- Rate limit: max 5 withdrawal requests per 24 hours
  PERFORM public.check_rate_limit(v_user_id, 'withdrawal_request', 5, 86400);

  -- Check sufficient diamond balance
  SELECT diamonds INTO v_balance
  FROM public.profiles
  WHERE id = v_user_id
  FOR UPDATE;  -- row-level lock prevents concurrent double-spend

  IF v_balance IS NULL OR v_balance < p_amount_diamonds THEN
    RAISE EXCEPTION 'Insufficient diamond balance. Have %, requested %.',
      COALESCE(v_balance, 0), p_amount_diamonds;
  END IF;

  -- Deduct diamonds
  UPDATE public.profiles
  SET diamonds = diamonds - p_amount_diamonds
  WHERE id = v_user_id;

  -- Create withdrawal request
  INSERT INTO public.withdrawal_requests (
    user_id, amount_diamonds, amount_naira,
    account_name, account_number, bank_code, bank_name, status
  )
  VALUES (
    v_user_id, p_amount_diamonds, p_amount_naira,
    p_account_name, p_account_number, p_bank_code, p_bank_name, 'pending'
  )
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$;

-- ============================================================
-- 8. Schedule daily cleanup via pg_cron (Pro / Business plans).
-- On Free plan, run SELECT public.cleanup_old_rate_limit_windows()
-- manually or trigger it from a daily Edge Function cron job.
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.schedule(
      'cleanup-rate-limits',      -- job name (unique)
      '0 3 * * *',                -- 03:00 UTC daily
      $cmd$SELECT public.cleanup_old_rate_limit_windows()$cmd$
    );
  END IF;
END;
$$;


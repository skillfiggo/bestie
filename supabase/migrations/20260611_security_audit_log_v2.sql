-- ============================================================
-- SECURITY AUDIT LOG v2
-- Fixes and extends 20260501_security_audit_log.sql:
--   • log_security_event is now non-fatal (EXCEPTION guard)
--   • check_rate_limit now logs every breach automatically
--   • Added target_id index + compound query index
--   • Added purge_old_audit_logs() with configurable retention
--   • Added get_audit_log() admin RPC with filtering + pagination
--   • Added convenience wrappers: log_payment_event, log_admin_action
--   • pg_cron schedule for nightly purge
-- All statements use CREATE OR REPLACE / IF NOT EXISTS (safe to re-run).
-- ============================================================

-- ============================================================
-- 1. Table — ensure all columns exist (idempotent)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.security_audit_log (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id     uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  action       text        NOT NULL,
  target_id    uuid,
  target_table text,
  details      jsonb       NOT NULL DEFAULT '{}',
  ip_hint      text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.security_audit_log ENABLE ROW LEVEL SECURITY;

-- Admins can SELECT; nobody can INSERT/UPDATE/DELETE directly —
-- all writes go through SECURITY DEFINER functions only.
DROP POLICY IF EXISTS "Admins can view audit log"          ON public.security_audit_log;
DROP POLICY IF EXISTS "No direct insert on audit log"      ON public.security_audit_log;
DROP POLICY IF EXISTS "No direct update on audit log"      ON public.security_audit_log;
DROP POLICY IF EXISTS "No direct delete on audit log"      ON public.security_audit_log;

CREATE POLICY "Admins can view audit log"
  ON public.security_audit_log FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Explicit deny for direct writes from non-service-role callers
CREATE POLICY "No direct insert on audit log"
  ON public.security_audit_log FOR INSERT
  WITH CHECK (false);

CREATE POLICY "No direct update on audit log"
  ON public.security_audit_log FOR UPDATE
  USING (false);

CREATE POLICY "No direct delete on audit log"
  ON public.security_audit_log FOR DELETE
  USING (false);

-- ============================================================
-- 2. Indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at
  ON public.security_audit_log (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_log_actor
  ON public.security_audit_log (actor_id, created_at DESC);

-- New: fast lookup of all events that touched a specific user/resource
CREATE INDEX IF NOT EXISTS idx_audit_log_target
  ON public.security_audit_log (target_id, created_at DESC);

-- New: fast filtering by action type for admin dashboards
CREATE INDEX IF NOT EXISTS idx_audit_log_action
  ON public.security_audit_log (action, created_at DESC);

-- ============================================================
-- 3. FUNCTION: log_security_event  (non-fatal version)
--
-- Wrapped in EXCEPTION WHEN OTHERS so a logging failure NEVER
-- rolls back the parent transaction (e.g. an auto-ban or payment).
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_security_event(
  p_actor_id     uuid,
  p_action       text,
  p_target_id    uuid   DEFAULT NULL,
  p_target_table text   DEFAULT NULL,
  p_details      jsonb  DEFAULT '{}',
  p_ip_hint      text   DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.security_audit_log
    (actor_id, action, target_id, target_table, details, ip_hint)
  VALUES
    (p_actor_id, p_action, p_target_id, p_target_table,
     COALESCE(p_details, '{}'), p_ip_hint);
EXCEPTION WHEN OTHERS THEN
  -- Log to Postgres log but never propagate — audit must not break app flows
  RAISE WARNING 'log_security_event failed (action=%, actor=%): %',
    p_action, p_actor_id, SQLERRM;
END;
$$;

-- ============================================================
-- 4. FUNCTION: log_rate_limit_breach  (fixed details structure)
--
-- Called automatically by check_rate_limit on every violation.
-- Also callable directly from edge functions for extra context.
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_rate_limit_breach(
  p_user_id     uuid,
  p_action      text,
  p_max_calls   integer DEFAULT NULL,
  p_window_secs integer DEFAULT NULL,
  p_extra       jsonb   DEFAULT '{}'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.log_security_event(
    p_user_id,
    'rate_limit_breach',
    p_user_id,
    'api_rate_limits',
    jsonb_build_object(
      'blocked_action', p_action,
      'limit',          p_max_calls,
      'window_secs',    p_window_secs
    ) || COALESCE(p_extra, '{}')
  );
END;
$$;

-- ============================================================
-- 5. Update check_rate_limit to log every breach automatically
-- (Replaces the version from 20260611_rate_limiting_v2.sql)
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id     uuid,
  p_action      text,
  p_max_calls   integer,
  p_window_secs integer
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
  -- Stable window boundary: floor(epoch / window) * window
  v_window_start := to_timestamp(
    (floor(extract(epoch from now()) / p_window_secs) * p_window_secs)::bigint
  );

  -- Read count BEFORE incrementing (avoids off-by-one)
  SELECT call_count INTO v_current_count
  FROM public.api_rate_limits
  WHERE user_id     = p_user_id
    AND action      = p_action
    AND window_start = v_window_start;

  IF FOUND AND v_current_count >= p_max_calls THEN
    -- Audit every breach (non-fatal — uses its own exception handler)
    PERFORM public.log_rate_limit_breach(p_user_id, p_action, p_max_calls, p_window_secs);

    RAISE EXCEPTION 'Rate limit exceeded for action "%". Retry after the current window expires. (code: 429)', p_action
      USING HINT = 'rate_limit_exceeded';
  END IF;

  -- Atomic upsert
  INSERT INTO public.api_rate_limits (user_id, action, window_start, call_count)
  VALUES (p_user_id, p_action, v_window_start, 1)
  ON CONFLICT (user_id, action, window_start)
  DO UPDATE SET
    call_count = api_rate_limits.call_count + 1,
    updated_at = now();
END;
$$;

-- ============================================================
-- 6. FUNCTION: log_payment_event  (convenience wrapper)
-- Call from edge functions after payment success/failure.
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_payment_event(
  p_actor_id  uuid,
  p_action    text,    -- e.g. 'payment_success', 'payment_failed', 'payment_duplicate'
  p_reference text,
  p_amount    numeric  DEFAULT NULL,
  p_coins     integer  DEFAULT NULL,
  p_provider  text     DEFAULT NULL,
  p_error     text     DEFAULT NULL,
  p_ip_hint   text     DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.log_security_event(
    p_actor_id,
    p_action,
    p_actor_id,
    'payment_history',
    jsonb_strip_nulls(jsonb_build_object(
      'reference', p_reference,
      'amount',    p_amount,
      'coins',     p_coins,
      'provider',  p_provider,
      'error',     p_error
    )),
    p_ip_hint
  );
END;
$$;

-- ============================================================
-- 7. FUNCTION: log_admin_action  (convenience wrapper)
-- For approve/reject withdrawal, manual ban/unban, etc.
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_admin_action(
  p_admin_id     uuid,
  p_action       text,    -- e.g. 'approve_withdrawal', 'reject_withdrawal'
  p_target_id    uuid     DEFAULT NULL,
  p_target_table text     DEFAULT NULL,
  p_details      jsonb    DEFAULT '{}',
  p_ip_hint      text     DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
BEGIN
  -- Verify the caller really is an admin before logging as one
  SELECT (role = 'admin') INTO v_is_admin
  FROM public.profiles WHERE id = p_admin_id;

  PERFORM public.log_security_event(
    p_admin_id,
    p_action,
    p_target_id,
    p_target_table,
    jsonb_build_object('is_admin_verified', COALESCE(v_is_admin, false))
      || COALESCE(p_details, '{}'),
    p_ip_hint
  );
END;
$$;

-- ============================================================
-- 8. FUNCTION: get_audit_log  (admin query RPC)
-- Paginated, filterable audit log viewer for the admin panel.
-- Usage: SELECT * FROM get_audit_log('ban_user', null, null, 50, 0)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_audit_log(
  p_action       text     DEFAULT NULL,   -- filter by action (exact match)
  p_actor_id     uuid     DEFAULT NULL,   -- filter by who did it
  p_target_id    uuid     DEFAULT NULL,   -- filter by who/what was affected
  p_limit        integer  DEFAULT 50,
  p_offset       integer  DEFAULT 0,
  p_since        timestamptz DEFAULT NULL -- only events after this time
)
RETURNS TABLE (
  id           uuid,
  actor_id     uuid,
  action       text,
  target_id    uuid,
  target_table text,
  details      jsonb,
  ip_hint      text,
  created_at   timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Callers must be admins
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  RETURN QUERY
  SELECT
    l.id, l.actor_id, l.action, l.target_id,
    l.target_table, l.details, l.ip_hint, l.created_at
  FROM public.security_audit_log l
  WHERE
    (p_action    IS NULL OR l.action    = p_action)
    AND (p_actor_id  IS NULL OR l.actor_id  = p_actor_id)
    AND (p_target_id IS NULL OR l.target_id = p_target_id)
    AND (p_since     IS NULL OR l.created_at >= p_since)
  ORDER BY l.created_at DESC
  LIMIT  LEAST(p_limit, 500)   -- hard cap at 500 rows per call
  OFFSET p_offset;
END;
$$;

-- ============================================================
-- 9. FUNCTION: purge_old_audit_logs
-- Retains the last p_retain_days of logs (default 90 days).
-- Returns the count of deleted rows.
-- ============================================================
CREATE OR REPLACE FUNCTION public.purge_old_audit_logs(
  p_retain_days integer DEFAULT 90
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.security_audit_log
  WHERE created_at < now() - (p_retain_days || ' days')::interval;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  -- Log the purge itself so there's an audit trail of data deletion
  PERFORM public.log_security_event(
    NULL,
    'audit_log_purged',
    NULL,
    'security_audit_log',
    jsonb_build_object('rows_deleted', v_deleted, 'retain_days', p_retain_days)
  );

  RETURN v_deleted;
END;
$$;

-- ============================================================
-- 10. pg_cron: nightly purge at 02:00 UTC (Pro/Business only)
-- Free plan: run SELECT public.purge_old_audit_logs() manually.
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.schedule(
      'purge-audit-logs',
      '0 2 * * *',
      $cmd$SELECT public.purge_old_audit_logs(90)$cmd$
    );
  END IF;
END;
$$;

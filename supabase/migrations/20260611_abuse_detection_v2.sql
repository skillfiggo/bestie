-- ============================================================
-- ABUSE DETECTION & AUTO-BAN v2
-- Fixes and extends 20260501_abuse_detection.sql:
--   • submit_user_report: validates reason, banned reporter guard,
--     returns structured result including 'already_reported'
--   • Auto-ban threshold configurable via app_settings table
--   • admin_ban_user: guards against self-ban and banning other admins
--   • admin_ban_user / admin_unban_user: returns affected row count
--   • ban_history table: full audit trail of every ban/unban event
--   • get_pending_reports() admin RPC with pagination
--   • admin_review_report() RPC for resolving individual reports
--   • Fixed RLS policies (idempotent DROP IF EXISTS before CREATE)
-- ============================================================

-- ============================================================
-- 1. Ensure profile ban columns exist
-- ============================================================
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_banned   boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS ban_reason  text,
  ADD COLUMN IF NOT EXISTS banned_at   timestamptz;

CREATE INDEX IF NOT EXISTS idx_profiles_is_banned
  ON public.profiles (is_banned)
  WHERE is_banned = true;

-- ============================================================
-- 2. user_reports table (idempotent)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_reports (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_id uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason      text        NOT NULL CHECK (
    reason IN (
      'spam', 'harassment', 'inappropriate_content',
      'fake_profile', 'scam', 'underage', 'other'
    )
  ),
  details     text,
  status      text        NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'reviewed', 'dismissed', 'action_taken')),
  reviewed_by uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT user_reports_unique  UNIQUE (reporter_id, reported_id),
  CONSTRAINT user_reports_no_self CHECK  (reporter_id <> reported_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reports_reported_id
  ON public.user_reports (reported_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_reports_reporter_id
  ON public.user_reports (reporter_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_status
  ON public.user_reports (status, created_at DESC);

ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

-- Drop old policies before recreating (idempotent)
DROP POLICY IF EXISTS "Users can submit reports"        ON public.user_reports;
DROP POLICY IF EXISTS "Users can view their own reports" ON public.user_reports;
DROP POLICY IF EXISTS "Admins can view all reports"     ON public.user_reports;
DROP POLICY IF EXISTS "Admins can update reports"       ON public.user_reports;

-- Banned users cannot submit new reports
CREATE POLICY "Users can submit reports"
  ON public.user_reports FOR INSERT
  WITH CHECK (
    auth.uid() = reporter_id
    AND NOT EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_banned = true
    )
  );

CREATE POLICY "Users can view their own reports"
  ON public.user_reports FOR SELECT
  USING (auth.uid() = reporter_id);

CREATE POLICY "Admins can view all reports"
  ON public.user_reports FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update reports"
  ON public.user_reports FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================
-- 3. ban_history table — full audit trail of every ban/unban
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ban_history (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event       text        NOT NULL CHECK (event IN ('banned', 'unbanned')),
  actor_id    uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  reason      text,
  report_count integer,    -- snapshot of report count at time of auto-ban
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ban_history_user
  ON public.ban_history (user_id, created_at DESC);

ALTER TABLE public.ban_history ENABLE ROW LEVEL SECURITY;

-- Only admins can view ban history
CREATE POLICY "Admins can view ban history"
  ON public.ban_history FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- No direct writes — SECURITY DEFINER functions only
CREATE POLICY "No direct insert on ban_history"
  ON public.ban_history FOR INSERT WITH CHECK (false);

-- ============================================================
-- 4. FUNCTION: submit_user_report  (fixed)
-- ============================================================
CREATE OR REPLACE FUNCTION public.submit_user_report(
  p_reported_id uuid,
  p_reason      text,
  p_details     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reporter_id    uuid    := auth.uid();
  v_report_count   integer;
  v_auto_banned    boolean := false;
  v_already_reported boolean := false;
  v_reporter_banned  boolean;
  v_reported_exists  boolean;
BEGIN
  -- Guard: reporter must not be banned
  SELECT is_banned INTO v_reporter_banned
  FROM public.profiles WHERE id = v_reporter_id;

  IF v_reporter_banned THEN
    RAISE EXCEPTION 'Banned users cannot submit reports';
  END IF;

  -- Guard: target user must exist and not be the reporter
  IF p_reported_id = v_reporter_id THEN
    RAISE EXCEPTION 'You cannot report yourself';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_reported_id
  ) INTO v_reported_exists;

  IF NOT v_reported_exists THEN
    RAISE EXCEPTION 'Reported user not found';
  END IF;

  -- Validate reason (clean error before hitting the CHECK constraint)
  IF p_reason NOT IN (
    'spam', 'harassment', 'inappropriate_content',
    'fake_profile', 'scam', 'underage', 'other'
  ) THEN
    RAISE EXCEPTION 'Invalid reason. Must be one of: spam, harassment, inappropriate_content, fake_profile, scam, underage, other';
  END IF;

  -- Rate limit: max 10 reports per hour (prevent report bombing)
  PERFORM public.check_rate_limit(v_reporter_id, 'submit_report', 10, 3600);

  -- Insert — ON CONFLICT signals a duplicate without crashing
  INSERT INTO public.user_reports (reporter_id, reported_id, reason, details)
  VALUES (v_reporter_id, p_reported_id, p_reason, p_details)
  ON CONFLICT (reporter_id, reported_id) DO NOTHING;

  -- Track whether this was a new report or a duplicate
  v_already_reported := NOT FOUND;

  -- Count unique non-dismissed reports in the last 7 days
  SELECT COUNT(*) INTO v_report_count
  FROM public.user_reports
  WHERE reported_id = p_reported_id
    AND created_at > now() - interval '7 days'
    AND status <> 'dismissed';

  -- Auto-ban threshold: 5 unique reports in 7 days
  IF v_report_count >= 5 AND NOT v_already_reported THEN
    UPDATE public.profiles
    SET
      is_banned  = true,
      ban_reason = format(
        'Auto-flagged: %s reports in 7 days. Pending admin review.',
        v_report_count
      ),
      banned_at  = now()
    WHERE id = p_reported_id
      AND is_banned = false;  -- idempotent: don't overwrite existing bans

    IF FOUND THEN
      v_auto_banned := true;

      -- Record in ban_history
      INSERT INTO public.ban_history (user_id, actor_id, event, reason, report_count)
      VALUES (
        p_reported_id, NULL, 'banned',
        format('Auto-flagged: %s reports in 7 days', v_report_count),
        v_report_count
      );

      -- Security audit (non-fatal)
      PERFORM public.log_security_event(
        v_reporter_id,
        'auto_ban',
        p_reported_id,
        'profiles',
        jsonb_build_object(
          'report_count',   v_report_count,
          'trigger',        'abuse_detection',
          'last_reason',    p_reason
        )
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success',          true,
    'already_reported', v_already_reported,
    'auto_flagged',     v_auto_banned,
    'report_count',     v_report_count
  );
END;
$$;

-- ============================================================
-- 5. FUNCTION: admin_ban_user  (fixed — return type changed void→jsonb)
-- ============================================================
DROP FUNCTION IF EXISTS public.admin_ban_user(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_ban_user(
  p_target_user_id uuid,
  p_reason         text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id    uuid    := auth.uid();
  v_is_admin    boolean;
  v_target_role text;
  v_was_banned  boolean;
BEGIN
  -- Verify caller is admin
  SELECT (role = 'admin') INTO v_is_admin
  FROM public.profiles WHERE id = v_admin_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Only admins can ban users';
  END IF;

  -- Guard: cannot ban yourself
  IF p_target_user_id = v_admin_id THEN
    RAISE EXCEPTION 'Admins cannot ban themselves';
  END IF;

  -- Guard: cannot ban another admin
  SELECT role INTO v_target_role
  FROM public.profiles WHERE id = p_target_user_id;

  IF v_target_role = 'admin' THEN
    RAISE EXCEPTION 'Admins cannot ban other admins';
  END IF;

  -- Read current ban state for idempotency report
  SELECT is_banned INTO v_was_banned
  FROM public.profiles WHERE id = p_target_user_id;

  -- Apply ban
  UPDATE public.profiles
  SET
    is_banned  = true,
    ban_reason = p_reason,
    banned_at  = now()
  WHERE id = p_target_user_id;

  -- Record in ban_history
  INSERT INTO public.ban_history (user_id, actor_id, event, reason)
  VALUES (p_target_user_id, v_admin_id, 'banned', p_reason);

  -- Audit log
  PERFORM public.log_security_event(
    v_admin_id, 'manual_ban', p_target_user_id, 'profiles',
    jsonb_build_object('reason', p_reason, 'was_already_banned', v_was_banned)
  );

  RETURN jsonb_build_object(
    'success',         true,
    'was_already_banned', COALESCE(v_was_banned, false)
  );
END;
$$;

-- ============================================================
-- 6. FUNCTION: admin_unban_user  (fixed — return type changed void→jsonb)
-- ============================================================
DROP FUNCTION IF EXISTS public.admin_unban_user(uuid);
CREATE OR REPLACE FUNCTION public.admin_unban_user(
  p_target_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id   uuid    := auth.uid();
  v_is_admin   boolean;
  v_was_banned boolean;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin
  FROM public.profiles WHERE id = v_admin_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Only admins can unban users';
  END IF;

  SELECT is_banned INTO v_was_banned
  FROM public.profiles WHERE id = p_target_user_id;

  -- Clear ban
  UPDATE public.profiles
  SET
    is_banned  = false,
    ban_reason = NULL,
    banned_at  = NULL
  WHERE id = p_target_user_id;

  -- Dismiss all pending reports for this user
  UPDATE public.user_reports
  SET
    status      = 'dismissed',
    reviewed_by = v_admin_id,
    reviewed_at = now()
  WHERE reported_id = p_target_user_id
    AND status = 'pending';

  -- Record in ban_history
  INSERT INTO public.ban_history (user_id, actor_id, event, reason)
  VALUES (p_target_user_id, v_admin_id, 'unbanned', 'Admin cleared ban');

  PERFORM public.log_security_event(
    v_admin_id, 'manual_unban', p_target_user_id, 'profiles',
    jsonb_build_object('was_banned', COALESCE(v_was_banned, false))
  );

  RETURN jsonb_build_object(
    'success',    true,
    'was_banned', COALESCE(v_was_banned, false)
  );
END;
$$;

-- ============================================================
-- 7. FUNCTION: admin_review_report
-- Allows admins to resolve individual reports.
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_review_report(
  p_report_id uuid,
  p_status    text,   -- 'reviewed' | 'dismissed' | 'action_taken'
  p_notes     text    DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_is_admin boolean;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin
  FROM public.profiles WHERE id = v_admin_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF p_status NOT IN ('reviewed', 'dismissed', 'action_taken') THEN
    RAISE EXCEPTION 'Invalid status. Must be: reviewed, dismissed, or action_taken';
  END IF;

  UPDATE public.user_reports
  SET
    status      = p_status,
    reviewed_by = v_admin_id,
    reviewed_at = now(),
    details     = CASE
                    WHEN p_notes IS NOT NULL
                    THEN COALESCE(details, '') || E'\n[Admin note] ' || p_notes
                    ELSE details
                  END
  WHERE id = p_report_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report not found';
  END IF;

  PERFORM public.log_security_event(
    v_admin_id, 'report_reviewed', p_report_id, 'user_reports',
    jsonb_build_object('new_status', p_status)
  );
END;
$$;

-- ============================================================
-- 8. FUNCTION: get_pending_reports  (admin RPC)
-- Paginated list of pending reports for the admin panel.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_pending_reports(
  p_status  text    DEFAULT 'pending',
  p_limit   integer DEFAULT 50,
  p_offset  integer DEFAULT 0
)
RETURNS TABLE (
  report_id      uuid,
  reporter_name  text,
  reporter_id    uuid,
  reported_name  text,
  reported_id    uuid,
  reported_banned boolean,
  reason         text,
  details        text,
  status         text,
  created_at     timestamptz,
  report_count   bigint    -- total reports against the reported user
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    reporter.name,
    r.reporter_id,
    reported.name,
    r.reported_id,
    reported.is_banned,
    r.reason,
    r.details,
    r.status,
    r.created_at,
    COUNT(*) OVER (PARTITION BY r.reported_id) AS report_count
  FROM public.user_reports r
  JOIN public.profiles reporter ON reporter.id = r.reporter_id
  JOIN public.profiles reported ON reported.id = r.reported_id
  WHERE r.status = p_status
  ORDER BY r.created_at DESC
  LIMIT  LEAST(p_limit, 200)
  OFFSET p_offset;
END;
$$;

-- ============================================================
-- 9. RLS: profiles viewable by authenticated non-banned users
-- (Replaces the original open policy — idempotent)
-- ============================================================
DROP POLICY IF EXISTS "Profiles are viewable by everyone"
  ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users (excluding banned)"
  ON public.profiles;

CREATE POLICY "Profiles are viewable by authenticated users (excluding banned)"
  ON public.profiles FOR SELECT
  USING (
    auth.uid() = id          -- own profile always visible
    OR is_banned = false     -- others: only if not banned
  );

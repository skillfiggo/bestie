-- ============================================================
-- ABUSE DETECTION & AUTO-BAN
-- Tracks user reports and automatically flags accounts that
-- accumulate too many reports in a short time window.
-- ============================================================

-- 1. Ensure profiles has is_banned and ban_reason columns
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_banned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS ban_reason text,
  ADD COLUMN IF NOT EXISTS banned_at timestamptz;

-- Index for fast banned-user filtering
CREATE INDEX IF NOT EXISTS idx_profiles_is_banned
  ON public.profiles (is_banned)
  WHERE is_banned = true;

-- ============================================================
-- 2. USER REPORTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_reports (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason        text NOT NULL CHECK (
    reason IN (
      'spam', 'harassment', 'inappropriate_content',
      'fake_profile', 'scam', 'underage', 'other'
    )
  ),
  details       text,
  status        text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'reviewed', 'dismissed', 'action_taken')),
  reviewed_by   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),

  -- Prevent duplicate reports from the same person for the same target
  CONSTRAINT user_reports_unique UNIQUE (reporter_id, reported_id),
  -- Prevent self-reporting
  CONSTRAINT user_reports_no_self CHECK (reporter_id <> reported_id)
);

-- RLS
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

-- Users can submit reports (their own reporter_id only)
CREATE POLICY "Users can submit reports"
  ON public.user_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- Users can view their own submitted reports
CREATE POLICY "Users can view their own reports"
  ON public.user_reports FOR SELECT
  USING (auth.uid() = reporter_id);

-- Admins can view and update all reports
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_reports_reported_id
  ON public.user_reports (reported_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_reports_status
  ON public.user_reports (status);

-- ============================================================
-- 3. FUNCTION: submit_user_report
-- Handles report submission and triggers auto-ban check.
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
  v_reporter_id   uuid := auth.uid();
  v_report_count  integer;
  v_auto_banned   boolean := false;
BEGIN
  -- Rate limit: 10 reports per hour per reporter (prevent report bombing)
  PERFORM public.check_rate_limit(v_reporter_id, 'submit_report', 10, 3600);

  -- Insert the report (unique constraint prevents duplicate)
  INSERT INTO public.user_reports (reporter_id, reported_id, reason, details)
  VALUES (v_reporter_id, p_reported_id, p_reason, p_details)
  ON CONFLICT (reporter_id, reported_id) DO NOTHING;

  -- Count reports against this user in the last 7 days
  SELECT COUNT(*) INTO v_report_count
  FROM public.user_reports
  WHERE reported_id = p_reported_id
    AND created_at > now() - interval '7 days'
    AND status != 'dismissed';

  -- Auto-flag if 5+ unique reports in 7 days
  IF v_report_count >= 5 THEN
    -- Check if not already banned
    UPDATE public.profiles
    SET
      is_banned   = true,
      ban_reason  = format('Auto-flagged: %s reports in 7 days. Pending admin review.', v_report_count),
      banned_at   = now()
    WHERE id = p_reported_id
      AND is_banned = false;

    IF FOUND THEN
      v_auto_banned := true;

      -- Log to security audit log
      PERFORM public.log_security_event(
        NULL,
        'auto_ban',
        p_reported_id,
        'profiles',
        jsonb_build_object(
          'report_count', v_report_count,
          'trigger', 'abuse_detection',
          'reporter_id', v_reporter_id
        )
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'auto_flagged', v_auto_banned,
    'report_count', v_report_count
  );
END;
$$;

-- ============================================================
-- 4. FUNCTION: admin_ban_user (manual admin action)
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_ban_user(
  p_target_user_id uuid,
  p_reason         text
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
  -- Verify caller is admin
  SELECT (role = 'admin') INTO v_is_admin
  FROM public.profiles
  WHERE id = v_admin_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Only admins can ban users';
  END IF;

  UPDATE public.profiles
  SET
    is_banned   = true,
    ban_reason  = p_reason,
    banned_at   = now()
  WHERE id = p_target_user_id;

  -- Audit log
  PERFORM public.log_security_event(
    v_admin_id, 'manual_ban', p_target_user_id, 'profiles',
    jsonb_build_object('reason', p_reason)
  );
END;
$$;

-- ============================================================
-- 5. FUNCTION: admin_unban_user
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_unban_user(
  p_target_user_id uuid
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
  FROM public.profiles
  WHERE id = v_admin_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Only admins can unban users';
  END IF;

  UPDATE public.profiles
  SET
    is_banned   = false,
    ban_reason  = NULL,
    banned_at   = NULL
  WHERE id = p_target_user_id;

  -- Also dismiss all pending reports for this user
  UPDATE public.user_reports
  SET status = 'dismissed', reviewed_by = v_admin_id, reviewed_at = now()
  WHERE reported_id = p_target_user_id AND status = 'pending';

  PERFORM public.log_security_event(
    v_admin_id, 'manual_unban', p_target_user_id, 'profiles'
  );
END;
$$;

-- ============================================================
-- 6. Update discovery & chat RLS to exclude banned users
-- ============================================================
-- Add a banned-user filter to the profiles SELECT policy
-- (Replaces the existing open "viewable by everyone" policy)
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;

CREATE POLICY "Profiles are viewable by authenticated users (excluding banned)"
  ON public.profiles
  FOR SELECT
  USING (
    -- Own profile is always visible
    auth.uid() = id
    OR
    -- Other profiles: only if not banned
    (is_banned = false OR is_banned IS NULL)
  );

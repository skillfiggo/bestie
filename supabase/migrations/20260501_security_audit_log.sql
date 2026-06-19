-- ============================================================
-- SECURITY AUDIT LOG
-- Records sensitive admin actions and security events.
-- Helps detect attacks and provides post-incident forensics.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.security_audit_log (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  action        text NOT NULL,         -- e.g. 'approve_withdrawal', 'ban_user', 'rate_limit_breach'
  target_id     uuid,                  -- The user/resource acted upon (nullable)
  target_table  text,                  -- e.g. 'withdrawal_requests', 'profiles'
  details       jsonb DEFAULT '{}',    -- Freeform metadata (amounts, IPs, etc.)
  ip_hint       text,                  -- Best-effort IP from edge function headers
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- RLS: only admins can read audit logs; no one can write directly (SECURITY DEFINER only)
ALTER TABLE public.security_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view audit log"
  ON public.security_audit_log
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Index for fast time-based queries
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at
  ON public.security_audit_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_actor
  ON public.security_audit_log (actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_action
  ON public.security_audit_log (action);

-- ============================================================
-- FUNCTION: log_security_event
-- Call this from edge functions (via supabaseAdmin.rpc) or
-- other SECURITY DEFINER functions.
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_security_event(
  p_actor_id    uuid,
  p_action      text,
  p_target_id   uuid    DEFAULT NULL,
  p_target_table text   DEFAULT NULL,
  p_details     jsonb   DEFAULT '{}',
  p_ip_hint     text    DEFAULT NULL
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
    (p_actor_id, p_action, p_target_id, p_target_table, p_details, p_ip_hint);
END;
$$;

-- ============================================================
-- FUNCTION: log_rate_limit_breach
-- Convenience wrapper specifically for rate limit violations.
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_rate_limit_breach(
  p_user_id uuid,
  p_action  text,
  p_details jsonb DEFAULT '{}'
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
    NULL,
    NULL,
    jsonb_build_object('action', p_action) || p_details
  );
END;
$$;

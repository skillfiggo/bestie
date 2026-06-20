-- ============================================================
-- BESTIE ADMIN: Push Notifications Log Table
-- Run once in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS push_notifications (
  id           UUID         DEFAULT gen_random_uuid() PRIMARY KEY,
  title        TEXT         NOT NULL,
  body         TEXT         NOT NULL,
  image_url    TEXT,
  filter_type  TEXT         NOT NULL CHECK (filter_type IN ('all','inactive','no_photo','city')),
  filter_city  TEXT,
  sent_count   INT          DEFAULT 0,
  open_count   INT          DEFAULT 0,
  fail_count   INT          DEFAULT 0,
  created_by   UUID         REFERENCES profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ  DEFAULT NOW()
);

ALTER TABLE push_notifications ENABLE ROW LEVEL SECURITY;

-- Admins can do everything
CREATE POLICY "Admins manage notifications"
  ON push_notifications FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ── Open-rate tracking ───────────────────────────────────────
-- Called by the Flutter app when a user taps a push notification

CREATE OR REPLACE FUNCTION track_notification_open(p_notification_id UUID)
RETURNS VOID
LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$
  UPDATE push_notifications
  SET    open_count = open_count + 1
  WHERE  id = p_notification_id;
$$;

GRANT EXECUTE ON FUNCTION track_notification_open(UUID) TO authenticated;

-- ── Helper RPC: count eligible tokens per filter ─────────────
-- Used by the admin UI to preview audience size before sending

CREATE OR REPLACE FUNCTION count_push_audience(
  p_filter TEXT,
  p_city   TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$
  SELECT COUNT(*)
  FROM profiles
  WHERE fcm_token IS NOT NULL
    AND (
      (p_filter = 'all')
      OR (p_filter = 'inactive'  AND updated_at < NOW() - INTERVAL '7 days')
      OR (p_filter = 'no_photo'  AND (avatar_url IS NULL OR avatar_url = ''))
      OR (p_filter = 'city'      AND location ILIKE ('%' || p_city || '%'))
    );
$$;

GRANT EXECUTE ON FUNCTION count_push_audience(TEXT, TEXT) TO authenticated;

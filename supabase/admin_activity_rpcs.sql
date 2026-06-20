-- ============================================================
-- BESTIE ADMIN: Activity Analytics RPC Functions
-- Run this once in Supabase SQL Editor
-- ============================================================

-- 1. Hour-by-hour activity (last N days)
CREATE OR REPLACE FUNCTION get_hourly_activity(days_back INT DEFAULT 30)
RETURNS TABLE (hour_of_day INT, message_count BIGINT, unique_users BIGINT)
LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    EXTRACT(HOUR FROM created_at AT TIME ZONE 'Africa/Lagos')::INT AS hour_of_day,
    COUNT(*) AS message_count,
    COUNT(DISTINCT sender_id) AS unique_users
  FROM messages
  WHERE created_at >= NOW() - (days_back || ' days')::INTERVAL
  GROUP BY 1 ORDER BY 1;
$$;

-- 2. Day-of-week activity (0=Sun … 6=Sat)
CREATE OR REPLACE FUNCTION get_dow_activity(days_back INT DEFAULT 30)
RETURNS TABLE (day_of_week INT, message_count BIGINT, unique_users BIGINT)
LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    EXTRACT(DOW FROM created_at AT TIME ZONE 'Africa/Lagos')::INT AS day_of_week,
    COUNT(*) AS message_count,
    COUNT(DISTINCT sender_id) AS unique_users
  FROM messages
  WHERE created_at >= NOW() - (days_back || ' days')::INTERVAL
  GROUP BY 1 ORDER BY 1;
$$;

-- 3. Daily Active Users — one row per day
CREATE OR REPLACE FUNCTION get_daily_active_users(days_back INT DEFAULT 30)
RETURNS TABLE (activity_date DATE, dau BIGINT)
LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    DATE(created_at AT TIME ZONE 'Africa/Lagos') AS activity_date,
    COUNT(DISTINCT sender_id) AS dau
  FROM messages
  WHERE created_at >= NOW() - (days_back || ' days')::INTERVAL
  GROUP BY 1 ORDER BY 1;
$$;

-- 4. Monthly Active Users (last 30 days distinct senders)
CREATE OR REPLACE FUNCTION get_mau()
RETURNS BIGINT
LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$
  SELECT COUNT(DISTINCT sender_id)
  FROM messages
  WHERE created_at >= NOW() - INTERVAL '30 days';
$$;

-- 5. Retention curve — weekly cohorts, last 8 weeks
CREATE OR REPLACE FUNCTION get_retention_curve()
RETURNS TABLE (
  cohort_week TEXT,
  cohort_size BIGINT,
  day1_retained BIGINT,
  day7_retained BIGINT,
  day30_retained BIGINT
)
LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$
  WITH cohorts AS (
    SELECT id,
      DATE_TRUNC('week', created_at AT TIME ZONE 'Africa/Lagos')::DATE AS cohort_start
    FROM profiles
    WHERE created_at >= NOW() - INTERVAL '70 days'
  ),
  activity AS (
    SELECT DISTINCT sender_id,
      DATE(created_at AT TIME ZONE 'Africa/Lagos') AS active_date
    FROM messages
  )
  SELECT
    TO_CHAR(c.cohort_start, 'Mon DD') AS cohort_week,
    COUNT(DISTINCT c.id)             AS cohort_size,
    COUNT(DISTINCT CASE
      WHEN a.active_date BETWEEN c.cohort_start + 1 AND c.cohort_start + 2
      THEN c.id END)                 AS day1_retained,
    COUNT(DISTINCT CASE
      WHEN a.active_date BETWEEN c.cohort_start + 1 AND c.cohort_start + 8
      THEN c.id END)                 AS day7_retained,
    COUNT(DISTINCT CASE
      WHEN a.active_date BETWEEN c.cohort_start + 1 AND c.cohort_start + 31
      THEN c.id END)                 AS day30_retained
  FROM cohorts c
  LEFT JOIN activity a ON a.sender_id = c.id
  GROUP BY c.cohort_start
  ORDER BY c.cohort_start DESC
  LIMIT 8;
$$;

-- Grant execute to authenticated users (admin calls these)
GRANT EXECUTE ON FUNCTION get_hourly_activity(INT)  TO authenticated;
GRANT EXECUTE ON FUNCTION get_dow_activity(INT)     TO authenticated;
GRANT EXECUTE ON FUNCTION get_daily_active_users(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_mau()                 TO authenticated;
GRANT EXECUTE ON FUNCTION get_retention_curve()     TO authenticated;

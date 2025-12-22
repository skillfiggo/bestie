-- CRITICAL Fix for Update Events
-- Postgres sometimes requires 'REPLICA IDENTITY FULL' to broadcast the OLD and NEW values correctly during updates.
-- Without this, 'UPDATE' events might not fire or might be empty for listeners filtering by ID.

ALTER TABLE call_history REPLICA IDENTITY FULL;

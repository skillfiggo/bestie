-- CRITICAL: Enable Realtime for call_history table
-- Without this, the app connects to the socket but receives NO updates when calls end.

begin;
  -- Remove if already exists to avoid error (safe)
  alter publication supabase_realtime drop table call_history;
exception when others then
  -- Ignore error if table wasn't in publication
end;

-- Add table to publication
alter publication supabase_realtime add table call_history;

-- Verify it worked (optional check)
select * from pg_publication_tables where pubname = 'supabase_realtime';

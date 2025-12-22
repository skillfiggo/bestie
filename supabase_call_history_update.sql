-- 1. Add ended_at and ended_by columns
alter table public.call_history
add column if not exists ended_at timestamptz,
add column if not exists ended_by uuid;

-- 2. Create RLS policy for updating call status
-- This ensures both caller and receiver can update the call (to end or decline it)
-- Note: Check if you already have policies on this table.
create policy "caller_or_receiver_can_update_call"
on public.call_history
for update
using (
  auth.uid() = caller_id OR auth.uid() = receiver_id
);

-- 3. Add index for faster status filtering
create index if not exists idx_call_history_status
on public.call_history (status);

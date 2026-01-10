-- 1. Create Payment History Table
create table if not exists payment_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) not null,
  reference text unique not null,
  provider text not null, -- 'paystack', 'opay', 'google_pay'
  amount numeric not null,
  coins_added int not null,
  status text default 'success',
  created_at timestamptz default now()
);

-- Enable RLS
ALTER TABLE payment_history ENABLE ROW LEVEL SECURITY;

-- Policies
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'payment_history' AND policyname = 'Users can view own payment history'
    ) THEN
        CREATE POLICY "Users can view own payment history" ON payment_history FOR SELECT USING (auth.uid() = user_id);
    END IF;
END $$;

-- 2. Secure Function to Process Payment
-- This runs with 'security definer' meaning it has admin privileges
-- It checks if reference exists (via unique constraint on table)
-- If new, it inserts history AND updates profile coin balance atomically.

create or replace function process_successful_payment(
  p_user_id uuid,
  p_reference text,
  p_amount numeric,
  p_coins int,
  p_provider text
)
returns int -- Returns new coin balance
language plpgsql
security definer
as $$
declare
  v_new_balance int;
begin
  -- 1. Insert into history. If reference exists, this will fail with unique violation error.
  insert into payment_history (user_id, reference, provider, amount, coins_added)
  values (p_user_id, p_reference, p_provider, p_amount, p_coins);

  -- 2. Update Profile coins
  -- Using simple update. Ideally 'coins' should not be updated by client directly anymore.
  update profiles
  set coins = coins + p_coins
  where id = p_user_id
  returning coins into v_new_balance;

  return v_new_balance;
end;
$$;

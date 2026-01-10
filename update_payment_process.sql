CREATE OR REPLACE FUNCTION process_successful_payment(
  p_user_id uuid,
  p_reference text,
  p_amount numeric,
  p_coins int,
  p_provider text
)
returns int
language plpgsql
security definer
as $$
declare
  v_new_balance int;
  v_msg text;
begin
  -- 1. Insert into history. If reference exists, this will fail with unique violation error.
  insert into payment_history (user_id, reference, provider, amount, coins_added)
  values (p_user_id, p_reference, p_provider, p_amount, p_coins);

  -- 2. Update Profile coins
  update profiles
  set coins = coins + p_coins
  where id = p_user_id
  returning coins into v_new_balance;

  -- 3. Send Official Notification
  v_msg := '🎉 Recharge Successful! You have received ' || p_coins || ' coins. Your new balance is ' || v_new_balance || ' coins.';
  PERFORM send_official_message(p_user_id, v_msg);

  return v_new_balance;
end;
$$;

-- 1. Create coin_adjustments table
CREATE TABLE IF NOT EXISTS public.coin_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  reason TEXT NOT NULL CHECK (reason IN ('Goodwill gesture', 'Bug compensation', 'Fraud reversal', 'Other')),
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE public.coin_adjustments ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS Policies
DROP POLICY IF EXISTS "Admins can view coin adjustments" ON public.coin_adjustments;
CREATE POLICY "Admins can view coin adjustments" ON public.coin_adjustments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can insert coin adjustments" ON public.coin_adjustments;
CREATE POLICY "Admins can insert coin adjustments" ON public.coin_adjustments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 4. Create secure RPC function to perform coin adjustments
CREATE OR REPLACE FUNCTION public.adjust_user_coins(
  p_user_id UUID,
  p_amount INTEGER,
  p_reason TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify the caller is an admin
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  -- Validate reason enum check
  IF p_reason NOT IN ('Goodwill gesture', 'Bug compensation', 'Fraud reversal', 'Other') THEN
    RAISE EXCEPTION 'Invalid reason category';
  END IF;

  -- Update user profile coins balance
  UPDATE public.profiles
  SET coins = COALESCE(coins, 0) + p_amount
  WHERE id = p_user_id;

  -- Record the adjustment audit log
  INSERT INTO public.coin_adjustments (admin_id, user_id, amount, reason, description)
  VALUES (auth.uid(), p_user_id, p_amount, p_reason, p_description);

  -- Log admin activity in system security audit log
  PERFORM public.log_admin_action(
    auth.uid(),
    'manual_coin_adjustment',
    p_user_id,
    'profiles',
    jsonb_build_object(
      'amount', p_amount,
      'reason', p_reason,
      'description', p_description
    )
  );
END;
$$;

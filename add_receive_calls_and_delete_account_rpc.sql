-- Alter table profiles to add receive_calls and show_location if not exists
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS show_location BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS receive_calls BOOLEAN NOT NULL DEFAULT TRUE;

-- Backfill existing profiles
UPDATE public.profiles SET show_location = TRUE WHERE show_location IS NULL;
UPDATE public.profiles SET receive_calls = TRUE WHERE receive_calls IS NULL;

-- RPC function to allow users to self-delete their account safely
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- auth.uid() returns the user ID of the authenticated user invoking the RPC
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

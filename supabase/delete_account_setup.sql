-- Create a secure function to allow users to delete their own account
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with creator privileges (superuser)
SET search_path = public
AS $$
BEGIN
  -- Delete the user from auth.users. 
  -- Note: This will automatically cascade to public.profiles if your foreign key has ON DELETE CASCADE.
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

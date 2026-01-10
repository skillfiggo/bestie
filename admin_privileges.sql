-- Add Admin update policy for profiles
-- This allows users with role = 'admin' to update ANY profile
DROP POLICY IF EXISTS "Admins can update any profile" ON profiles;

CREATE POLICY "Admins can update any profile" ON public.profiles
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Ensure Admins can also view everything (though they already can via the general select policy)
-- But let's be explicit if we ever tighten it.
DROP POLICY IF EXISTS "Admins can select any profile" ON profiles;
CREATE POLICY "Admins can select any profile" ON public.profiles
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- IMPORTANT: Set your user as admin if you haven't yet
-- Replace 'YOUR_USER_ID' with your actual UUID if you know it, 
-- or run: UPDATE profiles SET role = 'admin' WHERE name = 'Your Name';

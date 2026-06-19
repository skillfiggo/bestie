-- Revoke API access to spatial_ref_sys since it's owned by supabase_admin and we can't enable RLS on it
REVOKE ALL ON TABLE public.spatial_ref_sys FROM anon, authenticated;

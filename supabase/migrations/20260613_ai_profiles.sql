-- =============================================================
-- AI Profiles Table
-- Stores AI companion characters created by admins.
-- Users browse these in the "Hot Talk" section.
-- =============================================================

CREATE TABLE IF NOT EXISTS public.ai_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    avatar_url TEXT NOT NULL DEFAULT '',
    bio TEXT NOT NULL DEFAULT '',
    personality TEXT NOT NULL DEFAULT '',   -- System prompt for Grok
    age INTEGER NOT NULL DEFAULT 22,
    interests TEXT[] DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Index for fetching active profiles
CREATE INDEX IF NOT EXISTS idx_ai_profiles_active ON public.ai_profiles (is_active) WHERE is_active = true;

-- =============================================================
-- RLS Policies
-- =============================================================
ALTER TABLE public.ai_profiles ENABLE ROW LEVEL SECURITY;

-- All authenticated users can READ active AI profiles
CREATE POLICY "Anyone can view active AI profiles"
    ON public.ai_profiles FOR SELECT
    TO authenticated
    USING (is_active = true);

-- Admins can view ALL AI profiles (including inactive)
CREATE POLICY "Admins can view all AI profiles"
    ON public.ai_profiles FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Only admins can INSERT
CREATE POLICY "Admins can create AI profiles"
    ON public.ai_profiles FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Only admins can UPDATE
CREATE POLICY "Admins can update AI profiles"
    ON public.ai_profiles FOR UPDATE
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

-- Only admins can DELETE
CREATE POLICY "Admins can delete AI profiles"
    ON public.ai_profiles FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Grant service_role full access (for Edge Functions)
GRANT ALL ON public.ai_profiles TO service_role;

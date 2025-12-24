-- ============================================
-- APP CONFIG TABLE (For Admin Settings)
-- ============================================

CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Allow public read access (so app users can see the banner)
CREATE POLICY "Public Read Access" ON app_config
  FOR SELECT USING (true);

-- Allow authenticated users (admins) to update
-- Ideally this should be restricted to admin role, but for now we allow authenticated
CREATE POLICY "Auth Update Access" ON app_config
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Auth Insert Access" ON app_config
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Insert default values
INSERT INTO app_config (key, value)
VALUES 
  ('home_ads', '["🎉 Premium discounts available now!", "🔥 Hot matches near you!", "💎 Verify your profile for free badge", "🚀 Boost your profile to get more views"]'::jsonb),
  ('home_banner_image', '"https://images.unsplash.com/photo-1474044158699-59270e99d211"'::jsonb)
ON CONFLICT (key) DO NOTHING;

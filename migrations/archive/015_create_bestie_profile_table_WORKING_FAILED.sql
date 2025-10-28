-- ============================================================================
-- MIGRATION 015: Create bestie_profile table (WORKING VERSION)
-- ============================================================================
-- Purpose: Store bestie-specific profile and planning context
-- This version works with Supabase permissions (no system catalog access needed)
-- ============================================================================

-- Drop the table completely if it exists (clean slate)
DROP TABLE IF EXISTS bestie_profile CASCADE;

-- Create bestie_profile table fresh
CREATE TABLE bestie_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  bestie_brief TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_bestie_per_wedding UNIQUE (bestie_user_id, wedding_id)
);

-- Create indexes
CREATE INDEX idx_bestie_profile_bestie_user ON bestie_profile(bestie_user_id);
CREATE INDEX idx_bestie_profile_wedding ON bestie_profile(wedding_id);
CREATE INDEX idx_bestie_profile_bestie_wedding ON bestie_profile(bestie_user_id, wedding_id);

-- Enable RLS
ALTER TABLE bestie_profile ENABLE ROW LEVEL SECURITY;

-- Drop and recreate policies (idempotent)
DROP POLICY IF EXISTS "Bestie can view own profile" ON bestie_profile;
CREATE POLICY "Bestie can view own profile"
  ON bestie_profile FOR SELECT TO authenticated
  USING (bestie_user_id = auth.uid());

DROP POLICY IF EXISTS "Bestie can create own profile" ON bestie_profile;
CREATE POLICY "Bestie can create own profile"
  ON bestie_profile FOR INSERT TO authenticated
  WITH CHECK (bestie_user_id = auth.uid());

DROP POLICY IF EXISTS "Bestie can update own profile" ON bestie_profile;
CREATE POLICY "Bestie can update own profile"
  ON bestie_profile FOR UPDATE TO authenticated
  USING (bestie_user_id = auth.uid())
  WITH CHECK (bestie_user_id = auth.uid());

DROP POLICY IF EXISTS "Bestie can delete own profile" ON bestie_profile;
CREATE POLICY "Bestie can delete own profile"
  ON bestie_profile FOR DELETE TO authenticated
  USING (bestie_user_id = auth.uid());

DROP POLICY IF EXISTS "Wedding members can view bestie profiles" ON bestie_profile;
CREATE POLICY "Wedding members can view bestie profiles"
  ON bestie_profile FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = bestie_profile.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Backend full access" ON bestie_profile;
CREATE POLICY "Backend full access"
  ON bestie_profile FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- Create update trigger function
CREATE OR REPLACE FUNCTION update_bestie_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_update_bestie_profile_updated_at ON bestie_profile;
CREATE TRIGGER trigger_update_bestie_profile_updated_at
  BEFORE UPDATE ON bestie_profile
  FOR EACH ROW
  EXECUTE FUNCTION update_bestie_profile_updated_at();

-- Verification
SELECT
  '✓ bestie_profile table created successfully' as status,
  COUNT(*) as column_count
FROM information_schema.columns
WHERE table_name = 'bestie_profile';

SELECT
  '✓ RLS policies created' as status,
  COUNT(*) as policy_count
FROM pg_policies
WHERE tablename = 'bestie_profile';

-- ============================================================================
-- COMPLETE - Table ready for use
-- ============================================================================

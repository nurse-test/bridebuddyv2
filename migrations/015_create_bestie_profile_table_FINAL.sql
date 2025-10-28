-- ============================================================================
-- MIGRATION 015: Create bestie_profile table (SIMPLEST VERSION)
-- ============================================================================
-- Purpose: Store bestie-specific profile and planning context
-- Solution: Use a new constraint name to avoid conflicts with orphaned constraints
-- ============================================================================

-- Drop the table completely if it exists
DROP TABLE IF EXISTS bestie_profile CASCADE;

-- Create bestie_profile table with NEW constraint name
CREATE TABLE bestie_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  bestie_brief TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- NEW constraint name to avoid orphaned constraint conflicts
  CONSTRAINT bestie_profile_unique_per_wedding UNIQUE (bestie_user_id, wedding_id)
);

-- Create indexes
CREATE INDEX idx_bestie_profile_bestie_user ON bestie_profile(bestie_user_id);
CREATE INDEX idx_bestie_profile_wedding ON bestie_profile(wedding_id);
CREATE INDEX idx_bestie_profile_bestie_wedding ON bestie_profile(bestie_user_id, wedding_id);

-- Enable RLS
ALTER TABLE bestie_profile ENABLE ROW LEVEL SECURITY;

-- Create policies
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
SELECT '✓ bestie_profile table created' as status;
SELECT '✓ ' || COUNT(*) || ' RLS policies' as status FROM pg_policies WHERE tablename = 'bestie_profile';

-- ============================================================================
-- SUCCESS - Table created with new constraint name
-- ============================================================================

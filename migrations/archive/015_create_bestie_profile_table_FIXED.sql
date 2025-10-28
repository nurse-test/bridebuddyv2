-- ============================================================================
-- MIGRATION 015: Create bestie_profile table (FIXED VERSION)
-- ============================================================================
-- Purpose: Store bestie-specific profile and planning context
-- Used by: api/accept-invite.js when a bestie accepts an invite
-- ============================================================================
-- This version handles the case where constraints may already exist
-- ============================================================================

-- Drop existing constraint if it exists (safe cleanup)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'unique_bestie_per_wedding'
  ) THEN
    ALTER TABLE bestie_profile DROP CONSTRAINT IF EXISTS unique_bestie_per_wedding;
  END IF;
END $$;

-- Create bestie_profile table if it doesn't exist
CREATE TABLE IF NOT EXISTS bestie_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,

  -- Bestie context and brief
  bestie_brief TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add constraint only if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'unique_bestie_per_wedding'
  ) THEN
    ALTER TABLE bestie_profile
    ADD CONSTRAINT unique_bestie_per_wedding
    UNIQUE (bestie_user_id, wedding_id);
  END IF;
END $$;

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_bestie_profile_bestie_user ON bestie_profile(bestie_user_id);
CREATE INDEX IF NOT EXISTS idx_bestie_profile_wedding ON bestie_profile(wedding_id);
CREATE INDEX IF NOT EXISTS idx_bestie_profile_bestie_wedding ON bestie_profile(bestie_user_id, wedding_id);

-- Enable RLS
ALTER TABLE bestie_profile ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (safe to re-create)
DROP POLICY IF EXISTS "Bestie can view own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Bestie can create own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Bestie can update own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Bestie can delete own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Wedding members can view bestie profiles" ON bestie_profile;
DROP POLICY IF EXISTS "Backend full access" ON bestie_profile;

-- Policy: Bestie can view their own profile
CREATE POLICY "Bestie can view own profile"
  ON bestie_profile
  FOR SELECT
  TO authenticated
  USING (bestie_user_id = auth.uid());

-- Policy: Bestie can create their own profile
CREATE POLICY "Bestie can create own profile"
  ON bestie_profile
  FOR INSERT
  TO authenticated
  WITH CHECK (bestie_user_id = auth.uid());

-- Policy: Bestie can update their own profile
CREATE POLICY "Bestie can update own profile"
  ON bestie_profile
  FOR UPDATE
  TO authenticated
  USING (bestie_user_id = auth.uid())
  WITH CHECK (bestie_user_id = auth.uid());

-- Policy: Bestie can delete their own profile
CREATE POLICY "Bestie can delete own profile"
  ON bestie_profile
  FOR DELETE
  TO authenticated
  USING (bestie_user_id = auth.uid());

-- Policy: Wedding members can view bestie profiles for their wedding
CREATE POLICY "Wedding members can view bestie profiles"
  ON bestie_profile
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = bestie_profile.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Policy: Backend full access (for invite acceptance)
CREATE POLICY "Backend full access"
  ON bestie_profile
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_bestie_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function
DROP TRIGGER IF EXISTS trigger_update_bestie_profile_updated_at ON bestie_profile;

CREATE TRIGGER trigger_update_bestie_profile_updated_at
  BEFORE UPDATE ON bestie_profile
  FOR EACH ROW
  EXECUTE FUNCTION update_bestie_profile_updated_at();

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify table exists
SELECT
  'Table check' as check_type,
  CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'bestie_profile'
  ) THEN '✓ bestie_profile exists' ELSE '✗ bestie_profile missing' END as status;

-- Verify RLS is enabled
SELECT
  'RLS check' as check_type,
  CASE WHEN rowsecurity THEN '✓ RLS enabled' ELSE '✗ RLS disabled' END as status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'bestie_profile';

-- Count policies
SELECT
  'Policies check' as check_type,
  COUNT(*) || ' policies created' as status
FROM pg_policies
WHERE tablename = 'bestie_profile';

SELECT
  '✓✓✓ MIGRATION 015 COMPLETE' as status,
  'bestie_profile table created/verified with RLS and policies' as message;

-- ============================================================================
-- COMPLETE
-- ============================================================================

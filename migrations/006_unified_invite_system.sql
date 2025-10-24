-- ============================================================================
-- MIGRATION 006: Unified Invite System for All Roles
-- ============================================================================
-- Purpose: Create unified one-time-use invite link system for partner,
--          co-planner, and bestie roles
-- Date: 2025-10-24
-- ============================================================================

-- ============================================================================
-- STEP 1: Update invite_codes table schema
-- ============================================================================

-- Add role column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invite_codes' AND column_name = 'role'
  ) THEN
    ALTER TABLE invite_codes ADD COLUMN role TEXT;
  END IF;
END $$;

-- Add wedding_profile_permissions column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invite_codes' AND column_name = 'wedding_profile_permissions'
  ) THEN
    ALTER TABLE invite_codes
      ADD COLUMN wedding_profile_permissions JSONB DEFAULT '{"read": false, "edit": false}'::jsonb;
  END IF;
END $$;

-- Add expires_at column (7 days from creation)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invite_codes' AND column_name = 'expires_at'
  ) THEN
    ALTER TABLE invite_codes
      ADD COLUMN expires_at TIMESTAMPTZ;
  END IF;
END $$;

-- Add invite_token column (will replace 'code' column)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invite_codes' AND column_name = 'invite_token'
  ) THEN
    ALTER TABLE invite_codes
      ADD COLUMN invite_token TEXT UNIQUE;
  END IF;
END $$;

-- Migrate existing data: copy 'code' to 'invite_token'
UPDATE invite_codes
SET invite_token = code
WHERE invite_token IS NULL AND code IS NOT NULL;

-- Set expires_at for existing invites (7 days from created_at)
UPDATE invite_codes
SET expires_at = created_at + INTERVAL '7 days'
WHERE expires_at IS NULL AND created_at IS NOT NULL;

-- Update role values to new format
UPDATE invite_codes
SET role = 'co_planner'
WHERE role = 'member';

-- Set default wedding_profile_permissions for existing invites
UPDATE invite_codes
SET wedding_profile_permissions = '{"read": true, "edit": false}'::jsonb
WHERE wedding_profile_permissions IS NULL AND role = 'co_planner';

UPDATE invite_codes
SET wedding_profile_permissions = '{"read": true, "edit": true}'::jsonb
WHERE wedding_profile_permissions IS NULL AND role = 'partner';

UPDATE invite_codes
SET wedding_profile_permissions = '{"read": false, "edit": false}'::jsonb
WHERE wedding_profile_permissions IS NULL AND role = 'bestie';

-- Make invite_token NOT NULL after migration
ALTER TABLE invite_codes
  ALTER COLUMN invite_token SET NOT NULL;

-- Make expires_at NOT NULL after migration
ALTER TABLE invite_codes
  ALTER COLUMN expires_at SET NOT NULL;

-- ============================================================================
-- STEP 2: Update constraints
-- ============================================================================

-- Drop old CHECK constraint on role if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_name = 'invite_codes'
    AND constraint_name LIKE '%role%check%'
  ) THEN
    ALTER TABLE invite_codes DROP CONSTRAINT IF EXISTS invite_codes_role_check;
  END IF;
END $$;

-- Add new CHECK constraint for all roles
ALTER TABLE invite_codes
  ADD CONSTRAINT invite_codes_role_check
  CHECK (role IN ('partner', 'co_planner', 'bestie'));

-- Make role NOT NULL
ALTER TABLE invite_codes
  ALTER COLUMN role SET NOT NULL;

-- ============================================================================
-- STEP 3: Create indexes for performance
-- ============================================================================

-- Index on invite_token for fast lookup
CREATE INDEX IF NOT EXISTS invite_codes_invite_token_idx
  ON invite_codes(invite_token)
  WHERE used IS NULL OR used = false;

-- Index on expires_at for cleanup queries
CREATE INDEX IF NOT EXISTS invite_codes_expires_at_idx
  ON invite_codes(expires_at);

-- Index for finding valid invites
CREATE INDEX IF NOT EXISTS invite_codes_valid_idx
  ON invite_codes(invite_token, expires_at)
  WHERE used IS NULL OR used = false;

-- ============================================================================
-- STEP 4: Add helpful functions
-- ============================================================================

-- Function to check if invite is valid
CREATE OR REPLACE FUNCTION is_invite_valid(token TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM invite_codes
    WHERE invite_token = token
      AND (used = false OR used IS NULL)
      AND expires_at > NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get invite details (safe for unauthenticated users)
CREATE OR REPLACE FUNCTION get_invite_details(token TEXT)
RETURNS TABLE (
  wedding_id UUID,
  role TEXT,
  is_valid BOOLEAN,
  is_expired BOOLEAN,
  is_used BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ic.wedding_id,
    ic.role,
    (ic.expires_at > NOW() AND (ic.used = false OR ic.used IS NULL)) AS is_valid,
    (ic.expires_at <= NOW()) AS is_expired,
    COALESCE(ic.used, false) AS is_used
  FROM invite_codes ic
  WHERE ic.invite_token = token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 5: RLS Policies for invite_codes
-- ============================================================================

-- Enable RLS if not already enabled
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "Users can view invites they created" ON invite_codes;
DROP POLICY IF EXISTS "Users can create invites for their weddings" ON invite_codes;
DROP POLICY IF EXISTS "Anyone can view invite by token" ON invite_codes;

-- Policy: Wedding members can view invites for their wedding
CREATE POLICY "Wedding members can view invites"
  ON invite_codes FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members wm
      WHERE wm.wedding_id = invite_codes.wedding_id
        AND wm.user_id = auth.uid()
    )
  );

-- Policy: Wedding owners can create invites
CREATE POLICY "Wedding owners can create invites"
  ON invite_codes FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM wedding_members wm
      WHERE wm.wedding_id = invite_codes.wedding_id
        AND wm.user_id = auth.uid()
        AND wm.role = 'owner'
    )
    AND created_by = auth.uid()
  );

-- Policy: Allow unauthenticated users to validate tokens (via function)
-- This is safe because the function only returns limited info
GRANT EXECUTE ON FUNCTION get_invite_details(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION is_invite_valid(TEXT) TO anon, authenticated;

-- ============================================================================
-- STEP 6: Create view for active invites
-- ============================================================================

CREATE OR REPLACE VIEW active_invites AS
SELECT
  ic.id,
  ic.wedding_id,
  ic.invite_token,
  ic.role,
  ic.wedding_profile_permissions,
  ic.created_by,
  ic.created_at,
  ic.expires_at,
  ic.used,
  ic.used_by,
  ic.used_at,
  wp.partner1_name,
  wp.partner2_name,
  u.email AS creator_email
FROM invite_codes ic
JOIN wedding_profiles wp ON ic.wedding_id = wp.id
LEFT JOIN auth.users u ON ic.created_by = u.id
WHERE (ic.used = false OR ic.used IS NULL)
  AND ic.expires_at > NOW();

-- Grant access to view
GRANT SELECT ON active_invites TO authenticated;

-- ============================================================================
-- STEP 7: Cleanup function for expired invites
-- ============================================================================

CREATE OR REPLACE FUNCTION cleanup_expired_invites()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  -- Delete expired, unused invites older than 30 days
  DELETE FROM invite_codes
  WHERE expires_at < NOW() - INTERVAL '30 days'
    AND (used = false OR used IS NULL);

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VERIFICATION QUERIES (commented out - uncomment to test)
-- ============================================================================

/*
-- Check table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'invite_codes'
ORDER BY ordinal_position;

-- Check constraints
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'invite_codes';

-- View active invites
SELECT * FROM active_invites;

-- Test invite validation function
SELECT is_invite_valid('test-token');

-- Count invites by role
SELECT role, COUNT(*)
FROM invite_codes
GROUP BY role;
*/

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Summary of changes:
-- ✅ Added invite_token (replaces code)
-- ✅ Added wedding_profile_permissions (JSONB)
-- ✅ Added expires_at (7 days from creation)
-- ✅ Updated role constraint to support partner, co_planner, bestie
-- ✅ Migrated existing data
-- ✅ Added indexes for performance
-- ✅ Created helper functions for validation
-- ✅ Updated RLS policies
-- ✅ Created active_invites view
-- ✅ Added cleanup function

-- Next steps:
-- 1. Deploy this migration to production
-- 2. Update API endpoints to use new schema
-- 3. Test invite creation and acceptance flow
-- 4. Schedule cleanup_expired_invites() to run daily

-- ============================================================================
-- MIGRATION 001: Add invited_by_user_id to wedding_members
-- ============================================================================
-- Purpose: Track who invited each member/bestie to the wedding
-- Part of: Phase 1 - Bestie Permission System Implementation
-- ============================================================================

-- ============================================================================
-- STEP 1: Add new columns to wedding_members table
-- ============================================================================

-- Add invited_by_user_id column
ALTER TABLE wedding_members
ADD COLUMN IF NOT EXISTS invited_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Add wedding_profile_permissions column with default
ALTER TABLE wedding_members
ADD COLUMN IF NOT EXISTS wedding_profile_permissions JSONB
DEFAULT '{"can_read": false, "can_edit": false}'::jsonb;

-- Add created_at timestamp if it doesn't exist
ALTER TABLE wedding_members
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================================
-- STEP 2: Create indexes for performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS wedding_members_invited_by_idx
ON wedding_members(invited_by_user_id);

CREATE INDEX IF NOT EXISTS wedding_members_created_at_idx
ON wedding_members(created_at DESC);

-- ============================================================================
-- STEP 3: Migrate existing data
-- ============================================================================

-- For existing owners: they invited themselves
UPDATE wedding_members
SET invited_by_user_id = user_id
WHERE role = 'owner'
  AND invited_by_user_id IS NULL;

-- For existing members/besties: look up who created the invite they used
UPDATE wedding_members wm
SET invited_by_user_id = ic.created_by
FROM invite_codes ic
WHERE ic.used_by = wm.user_id
  AND ic.wedding_id = wm.wedding_id
  AND wm.role IN ('member', 'bestie')
  AND wm.invited_by_user_id IS NULL;

-- For any remaining members without invited_by (edge case: direct DB inserts)
-- Set to wedding owner as fallback
UPDATE wedding_members wm
SET invited_by_user_id = wp.owner_id
FROM wedding_profiles wp
WHERE wm.wedding_id = wp.id
  AND wm.invited_by_user_id IS NULL;

-- ============================================================================
-- STEP 4: Add constraints
-- ============================================================================

-- Validate JSON structure for wedding_profile_permissions
ALTER TABLE wedding_members
ADD CONSTRAINT wedding_profile_permissions_valid_json
CHECK (
  jsonb_typeof(wedding_profile_permissions) = 'object'
  AND wedding_profile_permissions ? 'can_read'
  AND wedding_profile_permissions ? 'can_edit'
);

-- Comment explaining the column
COMMENT ON COLUMN wedding_members.invited_by_user_id IS
'User ID of the person who invited this member. For owners, this is themselves. For members/besties, this is the person who created the invite code they used.';

COMMENT ON COLUMN wedding_members.wedding_profile_permissions IS
'Permissions this member has to view/edit the main wedding profile. Format: {"can_read": boolean, "can_edit": boolean}';

-- ============================================================================
-- STEP 5: Verification queries
-- ============================================================================

-- Check all wedding_members now have invited_by_user_id
SELECT
  COUNT(*) FILTER (WHERE invited_by_user_id IS NOT NULL) as members_with_inviter,
  COUNT(*) FILTER (WHERE invited_by_user_id IS NULL) as members_without_inviter,
  COUNT(*) as total_members
FROM wedding_members;

-- Show sample of migrated data
SELECT
  wm.user_id,
  wm.wedding_id,
  wm.role,
  wm.invited_by_user_id,
  wm.wedding_profile_permissions,
  p.email as user_email,
  inviter.email as invited_by_email
FROM wedding_members wm
LEFT JOIN profiles p ON p.id = wm.user_id
LEFT JOIN profiles inviter ON inviter.id = wm.invited_by_user_id
ORDER BY wm.created_at DESC
LIMIT 10;

-- Check column exists and has correct type
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'wedding_members'
  AND column_name IN ('invited_by_user_id', 'wedding_profile_permissions', 'created_at')
ORDER BY column_name;

-- ============================================================================
-- ROLLBACK (if needed - run this to undo migration)
-- ============================================================================
/*
-- Uncomment to rollback this migration

-- Drop indexes
DROP INDEX IF EXISTS wedding_members_invited_by_idx;
DROP INDEX IF EXISTS wedding_members_created_at_idx;

-- Drop constraints
ALTER TABLE wedding_members DROP CONSTRAINT IF EXISTS wedding_profile_permissions_valid_json;

-- Remove columns
ALTER TABLE wedding_members DROP COLUMN IF EXISTS invited_by_user_id;
ALTER TABLE wedding_members DROP COLUMN IF EXISTS wedding_profile_permissions;
ALTER TABLE wedding_members DROP COLUMN IF EXISTS created_at;
*/

-- ============================================================================
-- COMPLETE
-- ============================================================================
-- wedding_members table now tracks:
-- 1. Who invited each member (invited_by_user_id)
-- 2. What permissions they have to wedding profile (wedding_profile_permissions)
-- 3. When they joined (created_at)
--
-- Next: Run 002_create_bestie_permissions_table.sql
-- ============================================================================

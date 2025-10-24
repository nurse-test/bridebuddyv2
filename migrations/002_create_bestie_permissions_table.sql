-- ============================================================================
-- MIGRATION 002: Create bestie_permissions table
-- ============================================================================
-- Purpose: Track permissions besties grant to their inviters
-- Enforces 1:1 bestie-inviter relationship
-- Part of: Phase 1 - Bestie Permission System Implementation
-- ============================================================================

-- ============================================================================
-- STEP 1: Create bestie_permissions table
-- ============================================================================

CREATE TABLE IF NOT EXISTS bestie_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- The bestie user (MOH/Best Man)
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- The person who invited the bestie (usually bride/groom)
  inviter_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- The wedding this permission applies to
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,

  -- Permissions bestie has granted TO their inviter for accessing bestie's knowledge
  -- Format: {"can_read": boolean, "can_edit": boolean}
  permissions JSONB NOT NULL DEFAULT '{"can_read": false, "can_edit": false}'::jsonb,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- ========================================================================
  -- CONSTRAINTS: Enforce 1:1 bestie-inviter relationship
  -- ========================================================================

  -- Each bestie can only have ONE permission record per wedding
  -- This enforces that a bestie belongs to exactly one inviter
  CONSTRAINT unique_bestie_per_wedding UNIQUE (bestie_user_id, wedding_id),

  -- Bestie cannot grant permissions to themselves
  CONSTRAINT bestie_not_inviter CHECK (bestie_user_id != inviter_user_id)
);

-- ============================================================================
-- STEP 2: Create indexes for performance
-- ============================================================================

-- Index for looking up bestie's permissions (most common query)
CREATE INDEX IF NOT EXISTS bestie_permissions_bestie_idx
ON bestie_permissions(bestie_user_id);

-- Index for looking up what besties an inviter has
CREATE INDEX IF NOT EXISTS bestie_permissions_inviter_idx
ON bestie_permissions(inviter_user_id);

-- Index for wedding-based queries
CREATE INDEX IF NOT EXISTS bestie_permissions_wedding_idx
ON bestie_permissions(wedding_id);

-- Composite index for the most common lookup pattern
CREATE INDEX IF NOT EXISTS bestie_permissions_bestie_wedding_idx
ON bestie_permissions(bestie_user_id, wedding_id);

-- ============================================================================
-- STEP 3: Add constraints for JSON validation
-- ============================================================================

-- Validate permissions JSON structure
ALTER TABLE bestie_permissions
ADD CONSTRAINT permissions_valid_json
CHECK (
  jsonb_typeof(permissions) = 'object'
  AND permissions ? 'can_read'
  AND permissions ? 'can_edit'
  AND (permissions->>'can_read')::text IN ('true', 'false')
  AND (permissions->>'can_edit')::text IN ('true', 'false')
);

-- ============================================================================
-- STEP 4: Add trigger for updated_at timestamp
-- ============================================================================

-- Create trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_bestie_permissions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_bestie_permissions_updated_at ON bestie_permissions;

CREATE TRIGGER trigger_update_bestie_permissions_updated_at
  BEFORE UPDATE ON bestie_permissions
  FOR EACH ROW
  EXECUTE FUNCTION update_bestie_permissions_updated_at();

-- ============================================================================
-- STEP 5: Add comments for documentation
-- ============================================================================

COMMENT ON TABLE bestie_permissions IS
'Tracks permissions that besties (MOH/Best Man) grant to their inviters for accessing the bestie''s private knowledge base. Enforces 1:1 bestie-inviter relationship via unique constraint.';

COMMENT ON COLUMN bestie_permissions.bestie_user_id IS
'The bestie (MOH/Best Man) who owns the permissions record and controls access to their knowledge.';

COMMENT ON COLUMN bestie_permissions.inviter_user_id IS
'The person who invited the bestie (usually bride/groom). This is who the bestie can grant access to.';

COMMENT ON COLUMN bestie_permissions.permissions IS
'Permissions the bestie has granted to their inviter. can_read: view bestie knowledge, can_edit: modify bestie knowledge. Default is no access.';

-- ============================================================================
-- STEP 6: Migrate existing bestie users
-- ============================================================================

-- Create permission records for all existing besties
INSERT INTO bestie_permissions (bestie_user_id, inviter_user_id, wedding_id, permissions)
SELECT
  wm.user_id as bestie_user_id,
  wm.invited_by_user_id as inviter_user_id,
  wm.wedding_id,
  '{"can_read": false, "can_edit": false}'::jsonb as permissions
FROM wedding_members wm
WHERE wm.role = 'bestie'
  AND wm.invited_by_user_id IS NOT NULL
ON CONFLICT (bestie_user_id, wedding_id) DO NOTHING;

-- ============================================================================
-- STEP 7: Verification queries
-- ============================================================================

-- Count bestie permission records created
SELECT
  COUNT(*) as total_bestie_permissions,
  COUNT(DISTINCT bestie_user_id) as unique_besties,
  COUNT(DISTINCT inviter_user_id) as unique_inviters,
  COUNT(DISTINCT wedding_id) as unique_weddings
FROM bestie_permissions;

-- Show sample of created permissions
SELECT
  bp.bestie_user_id,
  bp.inviter_user_id,
  bp.wedding_id,
  bp.permissions,
  bestie.email as bestie_email,
  inviter.email as inviter_email,
  wp.wedding_name
FROM bestie_permissions bp
LEFT JOIN profiles bestie ON bestie.id = bp.bestie_user_id
LEFT JOIN profiles inviter ON inviter.id = bp.inviter_user_id
LEFT JOIN wedding_profiles wp ON wp.id = bp.wedding_id
ORDER BY bp.created_at DESC
LIMIT 10;

-- Verify 1:1 constraint works (should have 1 row per bestie per wedding)
SELECT
  bestie_user_id,
  wedding_id,
  COUNT(*) as permission_records
FROM bestie_permissions
GROUP BY bestie_user_id, wedding_id
HAVING COUNT(*) > 1;
-- Should return 0 rows (no duplicates)

-- Check table structure
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'bestie_permissions'
ORDER BY ordinal_position;

-- ============================================================================
-- ROLLBACK (if needed - run this to undo migration)
-- ============================================================================
/*
-- Uncomment to rollback this migration

-- Drop trigger and function
DROP TRIGGER IF EXISTS trigger_update_bestie_permissions_updated_at ON bestie_permissions;
DROP FUNCTION IF EXISTS update_bestie_permissions_updated_at();

-- Drop indexes
DROP INDEX IF EXISTS bestie_permissions_bestie_idx;
DROP INDEX IF EXISTS bestie_permissions_inviter_idx;
DROP INDEX IF EXISTS bestie_permissions_wedding_idx;
DROP INDEX IF EXISTS bestie_permissions_bestie_wedding_idx;

-- Drop table
DROP TABLE IF EXISTS bestie_permissions CASCADE;
*/

-- ============================================================================
-- COMPLETE
-- ============================================================================
-- bestie_permissions table created with:
-- 1. 1:1 bestie-inviter relationship enforced
-- 2. Default no-access permissions
-- 3. All existing besties have permission records
-- 4. Indexes for efficient queries
--
-- Next: Run 003_create_bestie_knowledge_table.sql
-- ============================================================================

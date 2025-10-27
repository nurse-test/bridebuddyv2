-- ============================================================================
-- MIGRATION 013: Simplify Permissions - Owner vs Bestie Model
-- ============================================================================
-- Purpose: Drop multi-role complexity and rebuild around simple ownership
-- Changes:
--   1. Drop bestie_permissions table (granular access control)
--   2. Drop pending_updates table (manual approval workflow)
--   3. Drop vendor_tracker, budget_tracker, wedding_tasks (auxiliary tables)
--   4. Simplify wedding_members to only 'owner' and 'bestie' roles
--   5. Remove wedding_profile_permissions column
--   6. Create bestie_profile aggregate table
--   7. Update RLS policies for simplified model
-- ============================================================================

-- ============================================================================
-- STEP 1: Drop auxiliary tables that support granular permissions
-- ============================================================================

-- Drop pending_updates (manual approval workflow)
DROP TABLE IF EXISTS pending_updates CASCADE;

-- Drop bestie_permissions (granular bestie access control)
DROP TABLE IF EXISTS bestie_permissions CASCADE;

-- Drop vendor/budget/task trackers (scatter data across tables)
DROP TABLE IF EXISTS wedding_tasks CASCADE;
DROP TABLE IF EXISTS budget_tracker CASCADE;
DROP TABLE IF EXISTS vendor_tracker CASCADE;

-- Drop bestie_knowledge (replaced by bestie_profile)
DROP TABLE IF EXISTS bestie_knowledge CASCADE;

-- ============================================================================
-- STEP 2: Drop old invite_codes table (has partner/co_planner roles)
-- ============================================================================

-- Drop the old invite_codes table that supported multiple roles
DROP TABLE IF EXISTS invite_codes CASCADE;

-- ============================================================================
-- STEP 3: Backup existing wedding_members data
-- ============================================================================

-- Create a backup of current wedding_members before simplification
CREATE TABLE IF NOT EXISTS wedding_members_backup_20251027 AS
SELECT * FROM wedding_members;

-- ============================================================================
-- STEP 4: Simplify wedding_members table
-- ============================================================================

-- Drop wedding_profile_permissions column (no longer needed)
ALTER TABLE wedding_members
DROP COLUMN IF EXISTS wedding_profile_permissions CASCADE;

-- Update role constraint to only allow 'owner' and 'bestie'
ALTER TABLE wedding_members
DROP CONSTRAINT IF EXISTS wedding_members_role_check;

ALTER TABLE wedding_members
ADD CONSTRAINT wedding_members_role_check
CHECK (role IN ('owner', 'bestie'));

-- Update existing members to fit new model
-- Convert 'member', 'partner', 'co_planner' to 'owner' (assuming they had access)
UPDATE wedding_members
SET role = 'owner'
WHERE role IN ('member', 'partner', 'co_planner');

-- Keep 'bestie' as is, keep 'owner' as is

-- ============================================================================
-- STEP 5: Create simplified invite_codes table (owner/bestie only)
-- ============================================================================

CREATE TABLE IF NOT EXISTS invite_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  invite_token TEXT NOT NULL UNIQUE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Simplified: only 'owner' or 'bestie' roles
  role TEXT NOT NULL CHECK (role IN ('owner', 'bestie')),

  -- Expiration and usage tracking
  expires_at TIMESTAMPTZ NOT NULL,
  is_used BOOLEAN DEFAULT FALSE,
  used BOOLEAN DEFAULT FALSE,
  used_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  used_at TIMESTAMPTZ
);

-- Create indexes
CREATE INDEX IF NOT EXISTS invite_codes_wedding_id_idx ON invite_codes(wedding_id);
CREATE INDEX IF NOT EXISTS invite_codes_code_idx ON invite_codes(code);
CREATE INDEX IF NOT EXISTS invite_codes_invite_token_idx ON invite_codes(invite_token);
CREATE INDEX IF NOT EXISTS invite_codes_is_used_idx ON invite_codes(is_used);
CREATE INDEX IF NOT EXISTS invite_codes_expires_at_idx ON invite_codes(expires_at);

-- ============================================================================
-- STEP 6: Create bestie_profile aggregate table
-- ============================================================================

CREATE TABLE IF NOT EXISTS bestie_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,

  -- Auto-generated bestie context by Claude
  bestie_brief TEXT, -- High-level summary of bestie responsibilities
  event_details JSONB DEFAULT '{}'::jsonb, -- Bachelorette/bachelor party details
  guest_info JSONB DEFAULT '{}'::jsonb, -- Guest list for bestie events
  budget_info JSONB DEFAULT '{}'::jsonb, -- Bestie event budgets
  tasks JSONB DEFAULT '[]'::jsonb, -- Auto-assigned bestie tasks
  notes TEXT, -- Private bestie notes

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraint: One bestie profile per user per wedding
  CONSTRAINT unique_bestie_profile UNIQUE (bestie_user_id, wedding_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS bestie_profile_bestie_user_idx ON bestie_profile(bestie_user_id);
CREATE INDEX IF NOT EXISTS bestie_profile_wedding_idx ON bestie_profile(wedding_id);
CREATE INDEX IF NOT EXISTS bestie_profile_bestie_wedding_idx ON bestie_profile(bestie_user_id, wedding_id);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_bestie_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_bestie_profile_updated_at ON bestie_profile;

CREATE TRIGGER trigger_update_bestie_profile_updated_at
  BEFORE UPDATE ON bestie_profile
  FOR EACH ROW
  EXECUTE FUNCTION update_bestie_profile_updated_at();

-- Add table comment
COMMENT ON TABLE bestie_profile IS
'Aggregate table for bestie (MOH/Best Man) planning data. Claude auto-generates and maintains this profile with bestie responsibilities, event details, and tasks.';

-- ============================================================================
-- STEP 7: Create bestie_profile records for existing besties
-- ============================================================================

-- Auto-create bestie_profile for all existing besties
INSERT INTO bestie_profile (bestie_user_id, wedding_id, bestie_brief, created_at)
SELECT
  wm.user_id,
  wm.wedding_id,
  'Bestie profile created during migration. Claude will populate details through chat.',
  NOW()
FROM wedding_members wm
WHERE wm.role = 'bestie'
ON CONFLICT (bestie_user_id, wedding_id) DO NOTHING;

-- ============================================================================
-- STEP 8: Update RLS policies for simplified model
-- ============================================================================

-- === WEDDING_PROFILES RLS POLICIES (unchanged, already owner-based) ===

-- === WEDDING_MEMBERS RLS POLICIES (simplified) ===

-- Drop old policies
DROP POLICY IF EXISTS "Users can view wedding members" ON wedding_members;
DROP POLICY IF EXISTS "Users can join as owner" ON wedding_members;
DROP POLICY IF EXISTS "Users can join as member" ON wedding_members;
DROP POLICY IF EXISTS "Owners can manage members" ON wedding_members;

-- Recreate simplified policies
CREATE POLICY "Users can view wedding members"
ON wedding_members FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members wm2
    WHERE wm2.wedding_id = wedding_members.wedding_id
    AND wm2.user_id = auth.uid()
  )
);

CREATE POLICY "Users can join as owner"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND role = 'owner');

CREATE POLICY "Users can join as bestie via invite"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND role = 'bestie');

CREATE POLICY "Owners can update members"
ON wedding_members FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members wm2
    WHERE wm2.wedding_id = wedding_members.wedding_id
    AND wm2.user_id = auth.uid()
    AND wm2.role = 'owner'
  )
);

-- === BESTIE_PROFILE RLS POLICIES ===

-- Enable RLS
ALTER TABLE bestie_profile ENABLE ROW LEVEL SECURITY;

-- Bestie can view and manage their own profile
CREATE POLICY "Bestie can view own profile"
ON bestie_profile FOR SELECT
TO authenticated
USING (bestie_user_id = auth.uid());

CREATE POLICY "Bestie can update own profile"
ON bestie_profile FOR UPDATE
TO authenticated
USING (bestie_user_id = auth.uid());

-- Backend (Claude) can create and update bestie profiles
CREATE POLICY "Backend can manage bestie profiles"
ON bestie_profile FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- === INVITE_CODES RLS POLICIES ===

-- Enable RLS
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- Wedding owners can view and create invites
CREATE POLICY "Wedding owners can view invites"
ON invite_codes FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members wm
    WHERE wm.wedding_id = invite_codes.wedding_id
    AND wm.user_id = auth.uid()
    AND wm.role = 'owner'
  )
);

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

-- Backend can update invite usage
CREATE POLICY "Backend can manage invites"
ON invite_codes FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- === CHAT_MESSAGES RLS POLICIES (simplified) ===

-- Drop old policies
DROP POLICY IF EXISTS "Users can view own chat messages" ON chat_messages;
DROP POLICY IF EXISTS "Backend can insert messages" ON chat_messages;

-- Recreate policies - anyone in wedding can see all chat
CREATE POLICY "Wedding members can view chat"
ON chat_messages FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members wm
    WHERE wm.wedding_id = chat_messages.wedding_id
    AND wm.user_id = auth.uid()
  )
);

-- Only backend can insert messages
CREATE POLICY "Backend can manage messages"
ON chat_messages FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 9: Drop helper functions and views that are no longer needed
-- ============================================================================

-- Drop bestie permission views
DROP VIEW IF EXISTS my_bestie_permissions CASCADE;
DROP VIEW IF EXISTS my_besties CASCADE;
DROP VIEW IF EXISTS my_bestie_knowledge_summary CASCADE;
DROP VIEW IF EXISTS accessible_bestie_knowledge CASCADE;

-- Drop helper functions
DROP FUNCTION IF EXISTS search_bestie_knowledge(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_bestie_knowledge_summary(UUID, UUID) CASCADE;

-- ============================================================================
-- STEP 10: Verification queries
-- ============================================================================

-- Count roles in simplified wedding_members
SELECT
  role,
  COUNT(*) as count
FROM wedding_members
GROUP BY role
ORDER BY role;
-- Should only show 'owner' and 'bestie'

-- Count bestie profiles created
SELECT COUNT(*) as bestie_profiles FROM bestie_profile;

-- Show sample bestie profiles
SELECT
  bp.bestie_user_id,
  bp.wedding_id,
  p.email as bestie_email,
  wp.wedding_name,
  bp.bestie_brief,
  bp.created_at
FROM bestie_profile bp
LEFT JOIN profiles p ON p.id = bp.bestie_user_id
LEFT JOIN wedding_profiles wp ON wp.id = bp.wedding_id
ORDER BY bp.created_at DESC
LIMIT 10;

-- Verify invite_codes only has owner/bestie roles
SELECT DISTINCT role FROM invite_codes;
-- Should only show 'owner' and 'bestie' (or be empty if no invites yet)

-- Check that wedding_members no longer has wedding_profile_permissions column
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'wedding_members'
  AND column_name = 'wedding_profile_permissions';
-- Should return 0 rows

-- Verify dropped tables
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'pending_updates',
    'bestie_permissions',
    'vendor_tracker',
    'budget_tracker',
    'wedding_tasks',
    'bestie_knowledge'
  );
-- Should return 0 rows (all dropped)

-- ============================================================================
-- ROLLBACK (if needed)
-- ============================================================================
/*
-- Uncomment to rollback this migration (WARNING: DATA LOSS)

-- Restore wedding_members from backup
DROP TABLE IF EXISTS wedding_members CASCADE;
ALTER TABLE wedding_members_backup_20251027 RENAME TO wedding_members;

-- Drop new tables
DROP TABLE IF EXISTS bestie_profile CASCADE;
DROP TABLE IF EXISTS invite_codes CASCADE;

-- You would need to re-run migrations 002-011 to restore the old structure
*/

-- ============================================================================
-- COMPLETE
-- ============================================================================
-- Permission system simplified to owner vs bestie model:
-- 1. ✓ Dropped bestie_permissions table
-- 2. ✓ Dropped pending_updates table
-- 3. ✓ Dropped vendor_tracker, budget_tracker, wedding_tasks tables
-- 4. ✓ Dropped bestie_knowledge table
-- 5. ✓ Simplified wedding_members to 'owner' and 'bestie' only
-- 6. ✓ Removed wedding_profile_permissions column
-- 7. ✓ Created bestie_profile aggregate table
-- 8. ✓ Updated RLS policies for simplified model
-- 9. ✓ Migrated existing besties to new bestie_profile
--
-- Next steps:
-- - Update API endpoints to use new simplified model
-- - Update frontend to remove multi-role UI
-- ============================================================================

-- ============================================================================
-- MIGRATION 021: Fix Role System - Owner, Partner, Bestie ONLY
-- ============================================================================
-- Purpose: Clean up role system to support exactly 3 roles:
--          - owner: Person who created the wedding
--          - partner: Fiancé/spouse with full access
--          - bestie: Bridesmaids/groomsmen with limited access
--
-- Removes: co_planner, member, team member, and all other role variations
-- Date: 2025-10-29
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Update invite_codes table
-- ============================================================================

-- Drop old role constraint if it exists (must do this BEFORE updating data)
ALTER TABLE invite_codes DROP CONSTRAINT IF EXISTS invite_codes_role_check;

-- Update any existing NULL or invalid roles to 'bestie' FIRST
-- Set any NULL roles to 'bestie' as default
UPDATE invite_codes
SET role = 'bestie'
WHERE role IS NULL;

-- Update any existing 'co_planner' invites to 'bestie'
-- (co_planner is closest to bestie functionality)
UPDATE invite_codes
SET role = 'bestie'
WHERE role = 'co_planner' OR role = 'member';

-- Update any other invalid roles to 'bestie'
UPDATE invite_codes
SET role = 'bestie'
WHERE role NOT IN ('partner', 'bestie');

-- NOW add new constraint: Only 'partner' and 'bestie' can be invited
-- (owner is created during wedding creation, not via invite)
ALTER TABLE invite_codes
  ADD CONSTRAINT invite_codes_role_check
  CHECK (role IN ('partner', 'bestie'));

-- Make role NOT NULL now that all rows have valid values
ALTER TABLE invite_codes
  ALTER COLUMN role SET NOT NULL;

-- Update permissions for existing invites
-- Partner: Full access (read + edit)
UPDATE invite_codes
SET wedding_profile_permissions = '{"read": true, "edit": true}'::jsonb
WHERE role = 'partner'
  AND (wedding_profile_permissions IS NULL OR wedding_profile_permissions = '{}');

-- Bestie: View only (read, no edit)
UPDATE invite_codes
SET wedding_profile_permissions = '{"read": true, "edit": false}'::jsonb
WHERE role = 'bestie'
  AND (wedding_profile_permissions IS NULL OR wedding_profile_permissions = '{}');

-- ============================================================================
-- STEP 2: Update wedding_members table
-- ============================================================================

-- Drop old role constraint if it exists (must do this BEFORE updating data)
ALTER TABLE wedding_members DROP CONSTRAINT IF EXISTS wedding_members_role_check;

-- Update any existing NULL roles to 'bestie' FIRST
UPDATE wedding_members
SET role = 'bestie'
WHERE role IS NULL;

-- Update any existing 'co_planner' or 'member' roles to 'bestie'
UPDATE wedding_members
SET role = 'bestie'
WHERE role = 'co_planner' OR role = 'member';

-- Update any other invalid roles to 'bestie'
UPDATE wedding_members
SET role = 'bestie'
WHERE role NOT IN ('owner', 'partner', 'bestie');

-- NOW add new constraint: Only 'owner', 'partner', 'bestie'
ALTER TABLE wedding_members
  ADD CONSTRAINT wedding_members_role_check
  CHECK (role IN ('owner', 'partner', 'bestie'));

-- Make role NOT NULL now that all rows have valid values
ALTER TABLE wedding_members
  ALTER COLUMN role SET NOT NULL;

-- Update permissions for existing members
-- Owner: Full access (read + edit)
UPDATE wedding_members
SET wedding_profile_permissions = '{"can_read": true, "can_edit": true}'::jsonb
WHERE role = 'owner'
  AND (wedding_profile_permissions IS NULL OR wedding_profile_permissions = '{}');

-- Partner: Full access (read + edit)
UPDATE wedding_members
SET wedding_profile_permissions = '{"can_read": true, "can_edit": true}'::jsonb
WHERE role = 'partner'
  AND (wedding_profile_permissions IS NULL OR wedding_profile_permissions = '{}');

-- Bestie: View only (read, no edit)
UPDATE wedding_members
SET wedding_profile_permissions = '{"can_read": true, "can_edit": false}'::jsonb
WHERE role = 'bestie'
  AND (wedding_profile_permissions IS NULL OR wedding_profile_permissions = '{}');

-- ============================================================================
-- STEP 3: Update RLS policies to use new role names
-- ============================================================================

-- Update pending_updates policy (only owner and partner can approve updates)
DROP POLICY IF EXISTS "Owners can approve/reject updates" ON pending_updates;

CREATE POLICY "Owners and partners can approve/reject updates"
ON pending_updates FOR UPDATE
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role IN ('owner', 'partner')
  )
)
WITH CHECK (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role IN ('owner', 'partner')
  )
);

-- Update invite_codes policy (only owner and partner can create invites)
DROP POLICY IF EXISTS "Wedding owners can create invites" ON invite_codes;

CREATE POLICY "Owners and partners can create invites"
  ON invite_codes FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM wedding_members wm
      WHERE wm.wedding_id = invite_codes.wedding_id
        AND wm.user_id = auth.uid()
        AND wm.role IN ('owner', 'partner')
    )
    AND created_by = auth.uid()
  );

-- ============================================================================
-- STEP 4: Create helper view for role information
-- ============================================================================

DROP VIEW IF EXISTS wedding_member_roles;

CREATE OR REPLACE VIEW wedding_member_roles AS
SELECT
  wm.wedding_id,
  wm.user_id,
  wm.role,
  wm.wedding_profile_permissions,
  wm.invited_by_user_id,
  p.full_name,
  p.email,
  CASE
    WHEN wm.role = 'owner' THEN 'Owner'
    WHEN wm.role = 'partner' THEN 'Partner'
    WHEN wm.role = 'bestie' THEN 'Bestie'
    ELSE 'Unknown'
  END as role_display,
  CASE
    WHEN wm.role = 'owner' THEN 'Full access - Wedding creator'
    WHEN wm.role = 'partner' THEN 'Full access - Can view and edit everything'
    WHEN wm.role = 'bestie' THEN 'View access - Can view details, limited editing'
    ELSE 'Unknown access'
  END as permission_description
FROM wedding_members wm
LEFT JOIN profiles p ON wm.user_id = p.id;

GRANT SELECT ON wedding_member_roles TO authenticated;

-- ============================================================================
-- STEP 5: Update active_invites view
-- ============================================================================

DROP VIEW IF EXISTS active_invites;

CREATE OR REPLACE VIEW active_invites AS
SELECT
  ic.id,
  ic.wedding_id,
  ic.invite_token,
  ic.role,
  ic.wedding_profile_permissions,
  ic.created_by,
  ic.created_at,
  ic.is_used,
  ic.used_by,
  ic.used_at,
  wp.partner1_name,
  wp.partner2_name,
  CASE
    WHEN ic.role = 'partner' THEN 'Partner'
    WHEN ic.role = 'bestie' THEN 'Bestie'
    ELSE 'Unknown'
  END as role_display
FROM invite_codes ic
JOIN wedding_profiles wp ON ic.wedding_id = wp.id
WHERE (ic.is_used = false OR ic.is_used IS NULL);

GRANT SELECT ON active_invites TO authenticated;

-- ============================================================================
-- STEP 6: Add comments for documentation
-- ============================================================================

COMMENT ON COLUMN wedding_members.role IS 'Role of the member: owner (wedding creator), partner (fiancé/spouse), or bestie (bridesmaid/groomsman)';
COMMENT ON COLUMN invite_codes.role IS 'Role to be assigned when invite is accepted: partner or bestie';

COMMENT ON CONSTRAINT wedding_members_role_check ON wedding_members IS 'Only owner, partner, and bestie roles are allowed';
COMMENT ON CONSTRAINT invite_codes_role_check ON invite_codes IS 'Only partner and bestie can be invited (owner is created with wedding)';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Count members by role
DO $$
DECLARE
  owner_count INTEGER;
  partner_count INTEGER;
  bestie_count INTEGER;
  other_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO owner_count FROM wedding_members WHERE role = 'owner';
  SELECT COUNT(*) INTO partner_count FROM wedding_members WHERE role = 'partner';
  SELECT COUNT(*) INTO bestie_count FROM wedding_members WHERE role = 'bestie';
  SELECT COUNT(*) INTO other_count FROM wedding_members WHERE role NOT IN ('owner', 'partner', 'bestie');

  RAISE NOTICE 'Wedding Members Summary:';
  RAISE NOTICE '  Owners: %', owner_count;
  RAISE NOTICE '  Partners: %', partner_count;
  RAISE NOTICE '  Besties: %', bestie_count;
  RAISE NOTICE '  Other (should be 0): %', other_count;

  IF other_count > 0 THEN
    RAISE WARNING 'Found % members with invalid roles!', other_count;
  END IF;
END $$;

-- Count invites by role
DO $$
DECLARE
  partner_invite_count INTEGER;
  bestie_invite_count INTEGER;
  other_invite_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO partner_invite_count FROM invite_codes WHERE role = 'partner';
  SELECT COUNT(*) INTO bestie_invite_count FROM invite_codes WHERE role = 'bestie';
  SELECT COUNT(*) INTO other_invite_count FROM invite_codes WHERE role NOT IN ('partner', 'bestie');

  RAISE NOTICE 'Invite Codes Summary:';
  RAISE NOTICE '  Partner Invites: %', partner_invite_count;
  RAISE NOTICE '  Bestie Invites: %', bestie_invite_count;
  RAISE NOTICE '  Other (should be 0): %', other_invite_count;

  IF other_invite_count > 0 THEN
    RAISE WARNING 'Found % invite codes with invalid roles!', other_invite_count;
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

SELECT
  '✓ Migration 021 Complete' as status,
  'Role system updated: Owner, Partner, Bestie ONLY' as message;

-- Summary of changes:
-- ✅ Updated invite_codes role constraint (partner, bestie)
-- ✅ Updated wedding_members role constraint (owner, partner, bestie)
-- ✅ Migrated all co_planner and member roles to bestie
-- ✅ Updated permissions for all roles
-- ✅ Updated RLS policies for new role names
-- ✅ Created helper views for role information
-- ✅ Added documentation comments

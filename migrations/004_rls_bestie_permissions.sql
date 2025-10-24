-- ============================================================================
-- MIGRATION 004: RLS Policies for bestie_permissions
-- ============================================================================
-- Purpose: Secure bestie_permissions table with Row Level Security
-- Enforces: Bestie can only see/update their own permissions
-- Part of: Phase 1 - Bestie Permission System Implementation
-- ============================================================================

-- ============================================================================
-- STEP 1: Enable RLS on bestie_permissions
-- ============================================================================

ALTER TABLE bestie_permissions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 2: Drop existing policies (if any)
-- ============================================================================

DROP POLICY IF EXISTS "Bestie can view own permissions" ON bestie_permissions;
DROP POLICY IF EXISTS "Bestie can update own permissions" ON bestie_permissions;
DROP POLICY IF EXISTS "Inviter can view bestie permissions" ON bestie_permissions;
DROP POLICY IF EXISTS "Backend full access" ON bestie_permissions;
DROP POLICY IF EXISTS "Service role full access" ON bestie_permissions;

-- ============================================================================
-- STEP 3: Create RLS policies for besties
-- ============================================================================

-- POLICY 1: Bestie can SELECT only their own permission record
-- This ensures bestie CANNOT see other besties' permissions
CREATE POLICY "Bestie can view own permissions"
ON bestie_permissions FOR SELECT
TO authenticated
USING (bestie_user_id = auth.uid());

-- POLICY 2: Bestie can UPDATE only their own permission record
-- This allows bestie to grant/revoke access to their inviter
-- IMPORTANT: Cannot change bestie_user_id or inviter_user_id (fixed at creation)
CREATE POLICY "Bestie can update own permissions"
ON bestie_permissions FOR UPDATE
TO authenticated
USING (bestie_user_id = auth.uid())
WITH CHECK (
  bestie_user_id = auth.uid()
  AND bestie_user_id = (SELECT bestie_user_id FROM bestie_permissions WHERE id = bestie_permissions.id)
  AND inviter_user_id = (SELECT inviter_user_id FROM bestie_permissions WHERE id = bestie_permissions.id)
);

-- ============================================================================
-- STEP 4: Create RLS policies for inviters
-- ============================================================================

-- POLICY 3: Inviter can SELECT their bestie's permissions
-- This allows inviter to check what access they've been granted
CREATE POLICY "Inviter can view bestie permissions"
ON bestie_permissions FOR SELECT
TO authenticated
USING (inviter_user_id = auth.uid());

-- ============================================================================
-- STEP 5: Create RLS policy for backend/service role
-- ============================================================================

-- POLICY 4: Backend (service role) has full access
-- This allows API endpoints to create/manage permission records
CREATE POLICY "Backend full access"
ON bestie_permissions FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 6: Verification queries
-- ============================================================================

-- Check RLS is enabled
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'bestie_permissions';
-- Expected: rowsecurity = true

-- List all policies on bestie_permissions
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'bestie_permissions'
ORDER BY policyname;

-- Count policies
SELECT COUNT(*) as policy_count
FROM pg_policies
WHERE tablename = 'bestie_permissions';
-- Expected: 4 policies

-- Show policy details
SELECT
  policyname,
  cmd as operation,
  CASE
    WHEN roles = '{authenticated}' THEN 'authenticated users'
    WHEN roles = '{service_role}' THEN 'service role'
    ELSE roles::text
  END as applies_to
FROM pg_policies
WHERE tablename = 'bestie_permissions'
ORDER BY policyname;

-- ============================================================================
-- STEP 7: Test scenarios (commented out - run manually for testing)
-- ============================================================================
/*
-- These tests verify RLS policies work correctly
-- Replace 'BESTIE_USER_ID', 'OTHER_BESTIE_ID', 'INVITER_ID' with actual UUIDs

-- Test 1: Bestie can see their own permissions
-- Login as bestie user, then:
SELECT * FROM bestie_permissions WHERE bestie_user_id = auth.uid();
-- Should return: 1 row (their own record)

-- Test 2: Bestie CANNOT see other besties' permissions
-- Login as bestie user, then:
SELECT * FROM bestie_permissions WHERE bestie_user_id != auth.uid();
-- Should return: 0 rows (cannot see other besties)

-- Test 3: Bestie can update their own permissions
-- Login as bestie user, then:
UPDATE bestie_permissions
SET permissions = '{"can_read": true, "can_edit": false}'::jsonb
WHERE bestie_user_id = auth.uid();
-- Should succeed

-- Test 4: Bestie CANNOT update other besties' permissions
-- Login as bestie user, then:
UPDATE bestie_permissions
SET permissions = '{"can_read": true, "can_edit": true}'::jsonb
WHERE bestie_user_id = 'OTHER_BESTIE_ID';
-- Should fail (0 rows updated)

-- Test 5: Bestie CANNOT change who they granted permissions to
-- Login as bestie user, then:
UPDATE bestie_permissions
SET inviter_user_id = 'DIFFERENT_USER_ID'
WHERE bestie_user_id = auth.uid();
-- Should fail (WITH CHECK constraint)

-- Test 6: Inviter can see their bestie's permissions
-- Login as inviter user, then:
SELECT * FROM bestie_permissions WHERE inviter_user_id = auth.uid();
-- Should return: 1 row (their bestie's permission record)

-- Test 7: Inviter CANNOT update bestie's permissions
-- Login as inviter user, then:
UPDATE bestie_permissions
SET permissions = '{"can_read": true, "can_edit": true}'::jsonb
WHERE inviter_user_id = auth.uid();
-- Should fail (0 rows updated - no UPDATE policy for inviter)
*/

-- ============================================================================
-- STEP 8: Create helper views (optional but useful)
-- ============================================================================

-- View for besties to see their permission status
CREATE OR REPLACE VIEW my_bestie_permissions AS
SELECT
  bp.id,
  bp.wedding_id,
  bp.inviter_user_id,
  bp.permissions,
  bp.updated_at,
  p.email as inviter_email,
  p.full_name as inviter_name,
  wp.wedding_name
FROM bestie_permissions bp
LEFT JOIN profiles p ON p.id = bp.inviter_user_id
LEFT JOIN wedding_profiles wp ON wp.id = bp.wedding_id
WHERE bp.bestie_user_id = auth.uid();

COMMENT ON VIEW my_bestie_permissions IS
'Shows the current user''s bestie permissions if they are a bestie. Returns empty if user is not a bestie.';

-- View for inviters to see their besties
CREATE OR REPLACE VIEW my_besties AS
SELECT
  bp.id,
  bp.bestie_user_id,
  bp.wedding_id,
  bp.permissions,
  bp.created_at,
  p.email as bestie_email,
  p.full_name as bestie_name,
  wp.wedding_name
FROM bestie_permissions bp
LEFT JOIN profiles p ON p.id = bp.bestie_user_id
LEFT JOIN wedding_profiles wp ON wp.id = bp.wedding_id
WHERE bp.inviter_user_id = auth.uid();

COMMENT ON VIEW my_besties IS
'Shows all besties the current user has invited, along with what permissions they''ve been granted.';

-- ============================================================================
-- ROLLBACK (if needed - run this to undo migration)
-- ============================================================================
/*
-- Uncomment to rollback this migration

-- Drop views
DROP VIEW IF EXISTS my_bestie_permissions;
DROP VIEW IF EXISTS my_besties;

-- Drop all policies
DROP POLICY IF EXISTS "Bestie can view own permissions" ON bestie_permissions;
DROP POLICY IF EXISTS "Bestie can update own permissions" ON bestie_permissions;
DROP POLICY IF EXISTS "Inviter can view bestie permissions" ON bestie_permissions;
DROP POLICY IF EXISTS "Backend full access" ON bestie_permissions;

-- Disable RLS
ALTER TABLE bestie_permissions DISABLE ROW LEVEL SECURITY;
*/

-- ============================================================================
-- COMPLETE
-- ============================================================================
-- bestie_permissions RLS policies created:
-- 1. ✅ Bestie can SELECT only their own record
-- 2. ✅ Bestie can UPDATE only their own record (cannot change bestie_user_id or inviter_user_id)
-- 3. ✅ Inviter can SELECT to see what access they have
-- 4. ✅ Backend has full access for API operations
-- 5. ✅ Bestie CANNOT see other besties' permissions
-- 6. ✅ Bestie CANNOT update other besties' permissions
--
-- Helper views created:
-- - my_bestie_permissions: For besties to check their status
-- - my_besties: For inviters to see their besties
--
-- Next: Run 005_rls_bestie_knowledge.sql
-- ============================================================================

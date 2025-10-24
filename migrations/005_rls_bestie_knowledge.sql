-- ============================================================================
-- MIGRATION 005: RLS Policies for bestie_knowledge
-- ============================================================================
-- Purpose: Secure bestie_knowledge table with Row Level Security
-- Enforces: Bestie owns knowledge, inviter can access IF granted permission
-- Part of: Phase 1 - Bestie Permission System Implementation
-- ============================================================================

-- ============================================================================
-- STEP 1: Enable RLS on bestie_knowledge
-- ============================================================================

ALTER TABLE bestie_knowledge ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 2: Drop existing policies (if any)
-- ============================================================================

DROP POLICY IF EXISTS "Bestie can view own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can create own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can update own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can delete own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Inviter can view if granted access" ON bestie_knowledge;
DROP POLICY IF EXISTS "Inviter can edit if granted access" ON bestie_knowledge;
DROP POLICY IF EXISTS "Backend full access" ON bestie_knowledge;

-- ============================================================================
-- STEP 3: Create RLS policies for besties (full CRUD on own knowledge)
-- ============================================================================

-- POLICY 1: Bestie can SELECT all their own knowledge
CREATE POLICY "Bestie can view own knowledge"
ON bestie_knowledge FOR SELECT
TO authenticated
USING (bestie_user_id = auth.uid());

-- POLICY 2: Bestie can INSERT their own knowledge
CREATE POLICY "Bestie can create own knowledge"
ON bestie_knowledge FOR INSERT
TO authenticated
WITH CHECK (bestie_user_id = auth.uid());

-- POLICY 3: Bestie can UPDATE their own knowledge
CREATE POLICY "Bestie can update own knowledge"
ON bestie_knowledge FOR UPDATE
TO authenticated
USING (bestie_user_id = auth.uid())
WITH CHECK (bestie_user_id = auth.uid());

-- POLICY 4: Bestie can DELETE their own knowledge
CREATE POLICY "Bestie can delete own knowledge"
ON bestie_knowledge FOR DELETE
TO authenticated
USING (bestie_user_id = auth.uid());

-- ============================================================================
-- STEP 4: Create RLS policies for inviters (conditional access)
-- ============================================================================

-- POLICY 5: Inviter can SELECT bestie's knowledge IF:
--   1. Bestie has granted can_read = true
--   2. Knowledge is not marked as private (is_private = false)
CREATE POLICY "Inviter can view if granted access"
ON bestie_knowledge FOR SELECT
TO authenticated
USING (
  -- Check if inviter has been granted read permission
  EXISTS (
    SELECT 1
    FROM bestie_permissions bp
    WHERE bp.bestie_user_id = bestie_knowledge.bestie_user_id
      AND bp.inviter_user_id = auth.uid()
      AND bp.wedding_id = bestie_knowledge.wedding_id
      AND (bp.permissions->>'can_read')::boolean = true
  )
  -- And the knowledge is not marked as private
  AND is_private = false
);

-- POLICY 6: Inviter can UPDATE bestie's knowledge IF:
--   1. Bestie has granted can_edit = true
--   2. Knowledge is not marked as private (is_private = false)
--   3. Cannot change bestie_user_id (ownership)
CREATE POLICY "Inviter can edit if granted access"
ON bestie_knowledge FOR UPDATE
TO authenticated
USING (
  -- Check if inviter has been granted edit permission
  EXISTS (
    SELECT 1
    FROM bestie_permissions bp
    WHERE bp.bestie_user_id = bestie_knowledge.bestie_user_id
      AND bp.inviter_user_id = auth.uid()
      AND bp.wedding_id = bestie_knowledge.wedding_id
      AND (bp.permissions->>'can_edit')::boolean = true
  )
  -- And the knowledge is not marked as private
  AND is_private = false
)
WITH CHECK (
  -- Same permission check for WITH CHECK
  EXISTS (
    SELECT 1
    FROM bestie_permissions bp
    WHERE bp.bestie_user_id = bestie_knowledge.bestie_user_id
      AND bp.inviter_user_id = auth.uid()
      AND bp.wedding_id = bestie_knowledge.wedding_id
      AND (bp.permissions->>'can_edit')::boolean = true
  )
  -- Ensure inviter cannot change ownership
  AND bestie_user_id = (SELECT bestie_user_id FROM bestie_knowledge WHERE id = bestie_knowledge.id)
  -- And cannot make private knowledge editable
  AND is_private = false
);

-- ============================================================================
-- STEP 5: Create RLS policy for backend/service role
-- ============================================================================

-- POLICY 7: Backend (service role) has full access
-- This allows API endpoints to create/manage knowledge records
CREATE POLICY "Backend full access"
ON bestie_knowledge FOR ALL
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
WHERE tablename = 'bestie_knowledge';
-- Expected: rowsecurity = true

-- List all policies on bestie_knowledge
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'bestie_knowledge'
ORDER BY policyname;

-- Count policies
SELECT COUNT(*) as policy_count
FROM pg_policies
WHERE tablename = 'bestie_knowledge';
-- Expected: 7 policies

-- Show policy summary
SELECT
  policyname,
  cmd as operation,
  CASE
    WHEN roles = '{authenticated}' THEN 'authenticated users'
    WHEN roles = '{service_role}' THEN 'service role'
    ELSE roles::text
  END as applies_to
FROM pg_policies
WHERE tablename = 'bestie_knowledge'
ORDER BY cmd, policyname;

-- ============================================================================
-- STEP 7: Test scenarios (commented out - run manually for testing)
-- ============================================================================
/*
-- These tests verify RLS policies work correctly
-- Replace 'BESTIE_USER_ID', 'INVITER_ID', 'WEDDING_ID' with actual UUIDs

-- Test 1: Bestie can see all their own knowledge
-- Login as bestie user, then:
SELECT * FROM bestie_knowledge WHERE bestie_user_id = auth.uid();
-- Should return: All bestie's knowledge (including private)

-- Test 2: Bestie can create knowledge
-- Login as bestie user, then:
INSERT INTO bestie_knowledge (bestie_user_id, wedding_id, content, knowledge_type)
VALUES (auth.uid(), 'WEDDING_ID', 'Test note', 'note');
-- Should succeed

-- Test 3: Bestie can update their knowledge
-- Login as bestie user, then:
UPDATE bestie_knowledge
SET content = 'Updated content'
WHERE bestie_user_id = auth.uid() AND id = 'KNOWLEDGE_ID';
-- Should succeed

-- Test 4: Bestie can delete their knowledge
-- Login as bestie user, then:
DELETE FROM bestie_knowledge
WHERE bestie_user_id = auth.uid() AND id = 'KNOWLEDGE_ID';
-- Should succeed

-- Test 5: Inviter CANNOT see knowledge without permission
-- Login as inviter user (with can_read = false), then:
SELECT * FROM bestie_knowledge
WHERE wedding_id = 'WEDDING_ID';
-- Should return: 0 rows

-- Test 6: Grant read permission to inviter
-- Login as bestie user, then:
UPDATE bestie_permissions
SET permissions = '{"can_read": true, "can_edit": false}'::jsonb
WHERE bestie_user_id = auth.uid();

-- Test 7: Inviter CAN see non-private knowledge after permission granted
-- Login as inviter user (with can_read = true), then:
SELECT * FROM bestie_knowledge
WHERE wedding_id = 'WEDDING_ID';
-- Should return: All non-private knowledge

-- Test 8: Inviter CANNOT see private knowledge even with read permission
-- Login as inviter user (with can_read = true), then:
SELECT * FROM bestie_knowledge
WHERE wedding_id = 'WEDDING_ID' AND is_private = true;
-- Should return: 0 rows

-- Test 9: Inviter CANNOT edit without edit permission
-- Login as inviter user (with can_read = true, can_edit = false), then:
UPDATE bestie_knowledge
SET content = 'Trying to edit'
WHERE wedding_id = 'WEDDING_ID';
-- Should fail (0 rows updated)

-- Test 10: Grant edit permission to inviter
-- Login as bestie user, then:
UPDATE bestie_permissions
SET permissions = '{"can_read": true, "can_edit": true}'::jsonb
WHERE bestie_user_id = auth.uid();

-- Test 11: Inviter CAN edit non-private knowledge after permission granted
-- Login as inviter user (with can_edit = true), then:
UPDATE bestie_knowledge
SET content = 'Edited by inviter'
WHERE wedding_id = 'WEDDING_ID' AND is_private = false;
-- Should succeed

-- Test 12: Inviter CANNOT steal ownership
-- Login as inviter user (with can_edit = true), then:
UPDATE bestie_knowledge
SET bestie_user_id = auth.uid()
WHERE wedding_id = 'WEDDING_ID';
-- Should fail (WITH CHECK constraint)
*/

-- ============================================================================
-- STEP 8: Create helper views (optional but useful)
-- ============================================================================

-- View for besties to see their knowledge summary
CREATE OR REPLACE VIEW my_bestie_knowledge_summary AS
SELECT
  bk.wedding_id,
  bk.knowledge_type,
  COUNT(*) as total_items,
  COUNT(*) FILTER (WHERE bk.is_private = true) as private_items,
  COUNT(*) FILTER (WHERE bk.is_private = false) as shared_items,
  MAX(bk.updated_at) as last_updated
FROM bestie_knowledge bk
WHERE bk.bestie_user_id = auth.uid()
GROUP BY bk.wedding_id, bk.knowledge_type;

COMMENT ON VIEW my_bestie_knowledge_summary IS
'Shows a summary of the current user''s bestie knowledge grouped by wedding and type.';

-- View for inviters to see what knowledge they can access
CREATE OR REPLACE VIEW accessible_bestie_knowledge AS
SELECT
  bk.id,
  bk.bestie_user_id,
  bk.wedding_id,
  bk.content,
  bk.knowledge_type,
  bk.metadata,
  bk.created_at,
  bk.updated_at,
  bp.permissions->>'can_edit' as i_can_edit,
  p.email as bestie_email,
  p.full_name as bestie_name
FROM bestie_knowledge bk
INNER JOIN bestie_permissions bp
  ON bp.bestie_user_id = bk.bestie_user_id
  AND bp.wedding_id = bk.wedding_id
  AND bp.inviter_user_id = auth.uid()
  AND (bp.permissions->>'can_read')::boolean = true
LEFT JOIN profiles p ON p.id = bk.bestie_user_id
WHERE bk.is_private = false;

COMMENT ON VIEW accessible_bestie_knowledge IS
'Shows all bestie knowledge that the current user (as inviter) has been granted access to read. Does not include private knowledge.';

-- ============================================================================
-- ROLLBACK (if needed - run this to undo migration)
-- ============================================================================
/*
-- Uncomment to rollback this migration

-- Drop views
DROP VIEW IF EXISTS my_bestie_knowledge_summary;
DROP VIEW IF EXISTS accessible_bestie_knowledge;

-- Drop all policies
DROP POLICY IF EXISTS "Bestie can view own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can create own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can update own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can delete own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Inviter can view if granted access" ON bestie_knowledge;
DROP POLICY IF EXISTS "Inviter can edit if granted access" ON bestie_knowledge;
DROP POLICY IF EXISTS "Backend full access" ON bestie_knowledge;

-- Disable RLS
ALTER TABLE bestie_knowledge DISABLE ROW LEVEL SECURITY;
*/

-- ============================================================================
-- COMPLETE
-- ============================================================================
-- bestie_knowledge RLS policies created:
--
-- Bestie policies (full control):
-- 1. ✅ Bestie can SELECT all their own knowledge
-- 2. ✅ Bestie can INSERT new knowledge
-- 3. ✅ Bestie can UPDATE their own knowledge
-- 4. ✅ Bestie can DELETE their own knowledge
--
-- Inviter policies (conditional access):
-- 5. ✅ Inviter can SELECT if granted can_read AND not private
-- 6. ✅ Inviter can UPDATE if granted can_edit AND not private
-- 7. ✅ Backend has full access for API operations
--
-- Security features:
-- ✅ Private knowledge (is_private=true) is ALWAYS invisible to inviter
-- ✅ Inviter cannot steal ownership of knowledge
-- ✅ Permissions checked via JOIN to bestie_permissions table
-- ✅ Bestie has full control over their knowledge at all times
--
-- Helper views created:
-- - my_bestie_knowledge_summary: For besties to see stats
-- - accessible_bestie_knowledge: For inviters to see what they can access
--
-- ============================================================================
-- PHASE 1 COMPLETE!
-- ============================================================================
-- All database schema changes complete:
-- ✅ Migration 001: Added invited_by_user_id to wedding_members
-- ✅ Migration 002: Created bestie_permissions table
-- ✅ Migration 003: Created bestie_knowledge table
-- ✅ Migration 004: Added RLS policies for bestie_permissions
-- ✅ Migration 005: Added RLS policies for bestie_knowledge
--
-- Next Phase: Phase 2 - API Endpoints
-- Files to create:
-- - api/create-bestie-invite.js
-- - api/accept-bestie-invite.js
-- - api/get-my-bestie-permissions.js
-- - api/update-my-inviter-access.js
-- ============================================================================

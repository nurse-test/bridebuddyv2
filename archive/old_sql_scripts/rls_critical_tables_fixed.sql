-- ============================================================================
-- BRIDE BUDDY - CRITICAL RLS POLICIES (CORRECTED)
-- ============================================================================
-- Fixed version - removed non-existent "status" column references
-- Run in Supabase Dashboard → SQL Editor
-- ============================================================================

-- ============================================================================
-- PART 1: wedding_profiles
-- ============================================================================

ALTER TABLE wedding_profiles ENABLE ROW LEVEL SECURITY;

-- Clean slate
DROP POLICY IF EXISTS "Users can view their weddings" ON wedding_profiles;
DROP POLICY IF EXISTS "Users can create wedding as owner" ON wedding_profiles;
DROP POLICY IF EXISTS "Owners can update their wedding" ON wedding_profiles;
DROP POLICY IF EXISTS "Backend full access" ON wedding_profiles;

-- POLICY 1: Users can SELECT weddings they're members of
CREATE POLICY "Users can view their weddings"
ON wedding_profiles FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
    -- REMOVED: AND status = 'active' (column doesn't exist)
  )
);

-- POLICY 2: Users can INSERT one wedding (as owner)
CREATE POLICY "Users can create wedding as owner"
ON wedding_profiles FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

-- POLICY 3: Only wedding owner can UPDATE
CREATE POLICY "Owners can update their wedding"
ON wedding_profiles FOR UPDATE
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- POLICY 4: Backend (service role) has full access
CREATE POLICY "Backend full access"
ON wedding_profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- PART 2: wedding_members
-- ============================================================================

ALTER TABLE wedding_members ENABLE ROW LEVEL SECURITY;

-- Clean slate
DROP POLICY IF EXISTS "Users can view members of their wedding" ON wedding_members;
DROP POLICY IF EXISTS "Users can join as owner" ON wedding_members;
DROP POLICY IF EXISTS "Users can join as member" ON wedding_members;
DROP POLICY IF EXISTS "Owners can manage members" ON wedding_members;
DROP POLICY IF EXISTS "Backend full access" ON wedding_members;

-- POLICY 1: Users can SELECT members of their wedding(s)
CREATE POLICY "Users can view members of their wedding"
ON wedding_members FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
    -- REMOVED: AND status = 'active' (column doesn't exist)
  )
);

-- POLICY 2: Users can INSERT themselves as owner (wedding creation)
CREATE POLICY "Users can join as owner"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND role = 'owner'
);

-- POLICY 3: Users can INSERT themselves as member (joining via invite)
CREATE POLICY "Users can join as member"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND role != 'owner'
);

-- POLICY 4: Wedding owners can UPDATE members
CREATE POLICY "Owners can manage members"
ON wedding_members FOR UPDATE
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role = 'owner'
    -- REMOVED: AND status = 'active' (column doesn't exist)
  )
)
WITH CHECK (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role = 'owner'
    -- REMOVED: AND status = 'active' (column doesn't exist)
  )
);

-- POLICY 5: Backend (service role) has full access
CREATE POLICY "Backend full access"
ON wedding_members FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- ACTUAL SCHEMA USED
-- ============================================================================
-- Based on code analysis:
--
-- wedding_members table has these columns:
--   - wedding_id (uuid, foreign key to wedding_profiles.id)
--   - user_id (uuid, foreign key to auth.users.id)
--   - role (text: 'owner', 'member', etc.)
--
-- NO status column exists!
-- ============================================================================

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename IN ('wedding_profiles', 'wedding_members')
ORDER BY tablename;
-- Expected: rowsecurity = true for both

-- Count policies
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN ('wedding_profiles', 'wedding_members')
GROUP BY tablename
ORDER BY tablename;
-- Expected: wedding_profiles = 4, wedding_members = 5

-- List all policies
SELECT
  tablename,
  policyname,
  cmd as operation
FROM pg_policies
WHERE tablename IN ('wedding_profiles', 'wedding_members')
ORDER BY tablename, policyname;

-- ============================================================================
-- TESTING (EXAMPLES - DO NOT RUN AUTOMATICALLY)
-- ============================================================================
-- These are example queries to run manually after deployment.
-- They are commented out to prevent errors during migration.
-- ============================================================================

/*
-- Test 1: View your weddings (should work)
SELECT * FROM wedding_profiles;

-- Test 2: View wedding members (should work)
SELECT * FROM wedding_members;

-- Test 3: As owner, update wedding (should work)
UPDATE wedding_profiles
SET wedding_name = 'Test Update'
WHERE owner_id = auth.uid();
*/

-- ============================================================================
-- COMPLETE
-- ============================================================================

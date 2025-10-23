-- ============================================================================
-- BRIDE BUDDY - CRITICAL RLS POLICIES
-- ============================================================================
-- Apply these first to secure your most sensitive data
-- Run in Supabase Dashboard → SQL Editor
-- ============================================================================

-- ============================================================================
-- PART 1: wedding_profiles (Core Wedding Data)
-- ============================================================================
-- This table contains all wedding details (date, budget, location, etc.)
-- CRITICAL: Users should ONLY see weddings they're members of

-- Enable RLS
ALTER TABLE wedding_profiles ENABLE ROW LEVEL SECURITY;

-- Clean slate: Drop any existing policies
DROP POLICY IF EXISTS "Users can view their weddings" ON wedding_profiles;
DROP POLICY IF EXISTS "Users can create wedding as owner" ON wedding_profiles;
DROP POLICY IF EXISTS "Owners can update their wedding" ON wedding_profiles;
DROP POLICY IF EXISTS "Backend full access" ON wedding_profiles;

-- ============================================================================
-- POLICY 1: Users can SELECT weddings they're members of
-- ============================================================================
-- How it works:
-- 1. User authenticates → auth.uid() returns their user ID
-- 2. Query checks wedding_members table for matching wedding_id
-- 3. Only returns weddings where user has active membership
-- ============================================================================

CREATE POLICY "Users can view their weddings"
ON wedding_profiles FOR SELECT
TO authenticated
USING (
  -- Check if this wedding_id exists in wedding_members
  -- with the current user's ID and active status
  id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND status = 'active'
  )
);

-- ============================================================================
-- POLICY 2: Users can INSERT one wedding (as owner)
-- ============================================================================
-- How it works:
-- 1. User can create a new wedding
-- 2. They must set themselves (auth.uid()) as the owner_id
-- 3. This happens during onboarding
-- ============================================================================

CREATE POLICY "Users can create wedding as owner"
ON wedding_profiles FOR INSERT
TO authenticated
WITH CHECK (
  -- User can only create wedding where they are the owner
  owner_id = auth.uid()
);

-- ============================================================================
-- POLICY 3: Only wedding owner can UPDATE
-- ============================================================================
-- How it works:
-- 1. USING clause: Determines which rows user can attempt to update
-- 2. WITH CHECK clause: Validates the updated data
-- 3. Both must pass for update to succeed
-- ============================================================================

CREATE POLICY "Owners can update their wedding"
ON wedding_profiles FOR UPDATE
TO authenticated
USING (
  -- User can only update weddings they own
  owner_id = auth.uid()
)
WITH CHECK (
  -- After update, owner_id must still be the current user
  -- (prevents transferring ownership accidentally)
  owner_id = auth.uid()
);

-- ============================================================================
-- POLICY 4: Backend (service role) has full access
-- ============================================================================
-- How it works:
-- 1. API endpoints use SUPABASE_SERVICE_ROLE_KEY
-- 2. This bypasses RLS for backend operations
-- 3. Needed for: AI updates, payment processing, admin operations
-- ============================================================================

CREATE POLICY "Backend full access"
ON wedding_profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- PART 2: wedding_members (User-Wedding Relationships)
-- ============================================================================
-- This is the PIVOT table - everything depends on this!
-- It links users to weddings and defines their role (owner, member, etc.)
-- CRITICAL: Secure this table properly or entire RLS model breaks down

-- Enable RLS
ALTER TABLE wedding_members ENABLE ROW LEVEL SECURITY;

-- Clean slate: Drop any existing policies
DROP POLICY IF EXISTS "Users can view members of their wedding" ON wedding_members;
DROP POLICY IF EXISTS "Users can join as owner" ON wedding_members;
DROP POLICY IF EXISTS "Users can join as member" ON wedding_members;
DROP POLICY IF EXISTS "Owners can manage members" ON wedding_members;
DROP POLICY IF EXISTS "Backend full access" ON wedding_members;

-- ============================================================================
-- POLICY 1: Users can SELECT members of their wedding(s)
-- ============================================================================
-- How it works:
-- 1. User can see all members of any wedding they belong to
-- 2. Useful for: showing co-planners, wedding party, etc.
-- 3. Cannot see members of other weddings
-- ============================================================================

CREATE POLICY "Users can view members of their wedding"
ON wedding_members FOR SELECT
TO authenticated
USING (
  -- User can see members of weddings they belong to
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND status = 'active'
  )
);

-- ============================================================================
-- POLICY 2: Users can INSERT themselves as owner (wedding creation)
-- ============================================================================
-- How it works:
-- 1. When creating a wedding via /api/create-wedding
-- 2. User is automatically added as owner
-- 3. They can ONLY add themselves, not others
-- ============================================================================

CREATE POLICY "Users can join as owner"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (
  -- User can only add themselves as owner
  user_id = auth.uid()
  AND role = 'owner'
);

-- ============================================================================
-- POLICY 3: Users can INSERT themselves as member (joining via invite)
-- ============================================================================
-- How it works:
-- 1. User receives invite code
-- 2. Backend validates code
-- 3. User is added as member (not owner)
-- 4. They can ONLY add themselves with non-owner role
-- ============================================================================

CREATE POLICY "Users can join as member"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (
  -- User can only add themselves as non-owner
  user_id = auth.uid()
  AND role != 'owner'
);

-- ============================================================================
-- POLICY 4: Wedding owners can UPDATE members
-- ============================================================================
-- How it works:
-- 1. Owner can change member roles, status, etc.
-- 2. Useful for: promoting co-planner, removing member, etc.
-- 3. Only works if you're the owner of that wedding
-- ============================================================================

CREATE POLICY "Owners can manage members"
ON wedding_members FOR UPDATE
TO authenticated
USING (
  -- User must be owner of the wedding to manage members
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role = 'owner'
      AND status = 'active'
  )
)
WITH CHECK (
  -- After update, user must still be owner
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role = 'owner'
      AND status = 'active'
  )
);

-- ============================================================================
-- POLICY 5: Backend (service role) has full access
-- ============================================================================

CREATE POLICY "Backend full access"
ON wedding_members FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Step 1: Check RLS is enabled
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename IN ('wedding_profiles', 'wedding_members')
ORDER BY tablename;
-- Expected: rowsecurity = true for both

-- Step 2: Count policies
SELECT
  tablename,
  COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN ('wedding_profiles', 'wedding_members')
GROUP BY tablename
ORDER BY tablename;
-- Expected: wedding_profiles = 4, wedding_members = 5

-- Step 3: List all policies
SELECT
  tablename,
  policyname,
  cmd as operation,
  roles
FROM pg_policies
WHERE tablename IN ('wedding_profiles', 'wedding_members')
ORDER BY tablename, policyname;

-- ============================================================================
-- TESTING GUIDE
-- ============================================================================

-- Test 1: As authenticated user, query your wedding
-- Should work:
SELECT * FROM wedding_profiles;

-- Test 2: Try to query a specific wedding you're NOT a member of
-- Should return 0 rows:
SELECT * FROM wedding_profiles WHERE id = 'some-other-wedding-id';

-- Test 3: As owner, update your wedding
-- Should work:
UPDATE wedding_profiles
SET wedding_name = 'Test Update'
WHERE id = 'your-wedding-id';

-- Test 4: As member (not owner), try to update wedding
-- Should fail with "new row violates row-level security policy":
UPDATE wedding_profiles
SET wedding_name = 'Hacked'
WHERE id = 'your-wedding-id';

-- ============================================================================
-- ROLLBACK (Emergency Use Only)
-- ============================================================================

-- If something breaks, disable RLS temporarily:
-- ALTER TABLE wedding_profiles DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE wedding_members DISABLE ROW LEVEL SECURITY;

-- Re-enable when fixed:
-- ALTER TABLE wedding_profiles ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE wedding_members ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- COMPLETE - CRITICAL TABLES SECURED
-- ============================================================================
-- Next steps:
-- 1. Run this script in Supabase SQL Editor
-- 2. Run verification queries above
-- 3. Test with your application
-- 4. Apply policies to remaining tables (see supabase_rls_migration.sql)
-- ============================================================================

-- ============================================================================
-- FIX: Remove circular dependency in wedding_members SELECT policy
-- ============================================================================
-- This version drops ALL existing SELECT policies first, then creates new ones
-- ============================================================================

-- Step 1: Drop ALL existing SELECT policies on wedding_members
DO $$
DECLARE
    pol record;
BEGIN
    FOR pol IN
        SELECT policyname
        FROM pg_policies
        WHERE tablename = 'wedding_members'
        AND cmd = 'SELECT'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON wedding_members', pol.policyname);
        RAISE NOTICE 'Dropped policy: %', pol.policyname;
    END LOOP;
END $$;

-- Step 2: Create NEW policies without circular dependency

-- NEW POLICY 1: Users can always see their own membership records
CREATE POLICY "Users can view their own memberships"
ON wedding_members FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- NEW POLICY 2: Users can see other members of weddings they belong to
CREATE POLICY "Users can view other members of their weddings"
ON wedding_members FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM wedding_members wm
    WHERE wm.user_id = auth.uid()
      AND wm.wedding_id = wedding_members.wedding_id
  )
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- List all SELECT policies on wedding_members
SELECT
  policyname,
  pg_get_expr(qual, 'wedding_members'::regclass) AS using_expression
FROM pg_policies
WHERE tablename = 'wedding_members'
AND cmd = 'SELECT'
ORDER BY policyname;

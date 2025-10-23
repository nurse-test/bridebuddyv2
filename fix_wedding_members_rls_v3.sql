-- ============================================================================
-- FIX: Remove ALL circular dependencies in wedding_members RLS
-- ============================================================================
-- SOLUTION: Users can ONLY read their own membership records via RLS
-- Backend APIs must use service role client to query other members
-- This completely avoids any circular reference
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

-- Step 2: Create SINGLE policy - users can only see their own memberships
-- This is the ONLY safe policy that doesn't create circular references

CREATE POLICY "Users can view only their own memberships"
ON wedding_members FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- ============================================================================
-- IMPORTANT NOTES
-- ============================================================================
-- With this policy:
-- ✅ Users can query: SELECT * FROM wedding_members WHERE user_id = auth.uid()
-- ❌ Users CANNOT query other members of their wedding through RLS
--
-- To query other members, backend APIs should:
-- 1. Use supabaseService client (service role key, bypasses RLS)
-- 2. First verify user is member of the wedding
-- 3. Then query all members of that wedding
-- ============================================================================

-- VERIFICATION
SELECT
  policyname,
  cmd,
  pg_get_expr(qual, 'wedding_members'::regclass) AS using_expression
FROM pg_policies
WHERE tablename = 'wedding_members'
ORDER BY cmd, policyname;

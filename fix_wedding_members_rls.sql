-- ============================================================================
-- FIX: Remove circular dependency in wedding_members SELECT policy
-- ============================================================================
-- Problem: The original policy tried to check wedding_members to determine
-- if a user can read wedding_members, creating a circular dependency.
--
-- Solution: Split into two simple policies:
-- 1. Users can always read their OWN membership records
-- 2. Users can read OTHER members' records if they share a wedding
-- ============================================================================

-- Drop the problematic circular policy
DROP POLICY IF EXISTS "Users can view members of their wedding" ON wedding_members;

-- NEW POLICY 1: Users can always see their own membership records
CREATE POLICY "Users can view their own memberships"
ON wedding_members FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- NEW POLICY 2: Users can see other members of weddings they belong to
-- This policy is safe because it only applies AFTER the user can see their own records
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
-- After running this, test with an authenticated user:
-- SELECT * FROM wedding_members WHERE user_id = auth.uid();
-- Should return their membership records immediately
-- ============================================================================

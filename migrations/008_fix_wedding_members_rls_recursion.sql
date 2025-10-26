-- Migration 008: Fix RLS Policy Recursion in wedding_members
--
-- Problem: The "Users can view members of their wedding" policy creates infinite recursion
-- because it queries wedding_members from within a policy ON wedding_members.
--
-- Solution: Create a security definer function to break the recursion chain.

-- Step 1: Create a helper function that checks if a user is a member of a wedding
-- This function runs with SECURITY DEFINER, meaning it bypasses RLS policies
CREATE OR REPLACE FUNCTION is_wedding_member(p_wedding_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM wedding_members
    WHERE wedding_id = p_wedding_id
      AND user_id = p_user_id
  );
$$;

-- Step 2: Create another helper function to check if user is owner
CREATE OR REPLACE FUNCTION is_wedding_owner(p_wedding_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM wedding_members
    WHERE wedding_id = p_wedding_id
      AND user_id = p_user_id
      AND role = 'owner'
  );
$$;

-- Step 3: Drop the recursive policies
DROP POLICY IF EXISTS "Users can view members of their wedding" ON wedding_members;
DROP POLICY IF EXISTS "Users can view wedding members" ON wedding_members;
DROP POLICY IF EXISTS "Owners can manage members" ON wedding_members;

-- Step 4: Create non-recursive policies using the helper functions
CREATE POLICY "Users can view wedding members"
ON wedding_members FOR SELECT
TO authenticated
USING (
  -- Users can see members of weddings they're part of
  -- Uses security definer function to prevent recursion
  is_wedding_member(wedding_id, auth.uid())
);

CREATE POLICY "Owners can manage members"
ON wedding_members FOR UPDATE
TO authenticated
USING (
  -- Only owners can update members
  -- Uses security definer function to prevent recursion
  is_wedding_owner(wedding_id, auth.uid())
)
WITH CHECK (
  -- Ensure updated rows still belong to weddings the user owns
  is_wedding_owner(wedding_id, auth.uid())
);

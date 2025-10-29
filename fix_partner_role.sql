-- ============================================================================
-- FIX: Add 'partner' as valid role in wedding_members table
-- ============================================================================
-- This updates the CHECK constraint to allow 'partner' role
-- Run this in Supabase SQL Editor
-- ============================================================================

-- Drop the old CHECK constraint
ALTER TABLE wedding_members
DROP CONSTRAINT IF EXISTS wedding_members_role_check;

-- Add new CHECK constraint with 'partner' role
ALTER TABLE wedding_members
ADD CONSTRAINT wedding_members_role_check
CHECK (role IN ('owner', 'partner', 'bestie'));

-- Verify the constraint was updated
SELECT
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'wedding_members'::regclass
  AND conname = 'wedding_members_role_check';

-- ============================================================================
-- DONE!
-- ============================================================================
-- After running this SQL, the wedding_members table will accept:
--   - 'owner': Wedding creator (full access)
--   - 'partner': Fiancé(e) (full access)
--   - 'bestie': MOH/Best Man (bestie access only)
-- ============================================================================

-- ============================================================================
-- Migration 019: Add is_owner column to profiles table
-- ============================================================================
-- Purpose: Track which users own a wedding vs. being a member/bestie
-- This is needed for proper access control in the application
-- ============================================================================

-- Add is_owner column to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_owner BOOLEAN DEFAULT false;

-- Create index for faster lookups of wedding owners
CREATE INDEX IF NOT EXISTS profiles_is_owner_idx ON profiles(is_owner);

-- Update existing profiles to set is_owner = true if they're a wedding owner
UPDATE profiles
SET is_owner = true
WHERE id IN (
  SELECT user_id
  FROM wedding_members
  WHERE role = 'owner'
);

-- Add comment explaining the column
COMMENT ON COLUMN profiles.is_owner IS 'True if the user owns a wedding (has role=owner in wedding_members)';

-- ============================================================================
-- MIGRATION 020: Fix Invite Functions to Use Correct Column Names
-- ============================================================================
-- Purpose: Fix database functions created in migration 006 to use correct
--          column names (is_used instead of used, remove expires_at)
-- Issue: Functions reference 'used' column which doesn't exist (should be 'is_used')
-- Date: 2025-10-29
-- ============================================================================

-- ============================================================================
-- STEP 1: Drop and recreate is_invite_valid function
-- ============================================================================
-- This function checks if an invite token is valid
-- Fixed: used → is_used, removed expires_at check

DROP FUNCTION IF EXISTS is_invite_valid(TEXT);

CREATE OR REPLACE FUNCTION is_invite_valid(token TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM invite_codes
    WHERE invite_token = token
      AND (is_used = false OR is_used IS NULL)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 2: Drop and recreate get_invite_details function
-- ============================================================================
-- This function returns invite details for unauthenticated users
-- Fixed: used → is_used, removed expires_at references

DROP FUNCTION IF EXISTS get_invite_details(TEXT);

CREATE OR REPLACE FUNCTION get_invite_details(token TEXT)
RETURNS TABLE (
  wedding_id UUID,
  role TEXT,
  is_valid BOOLEAN,
  is_used BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ic.wedding_id,
    ic.role,
    (ic.is_used = false OR ic.is_used IS NULL) AS is_valid,
    COALESCE(ic.is_used, false) AS is_used
  FROM invite_codes ic
  WHERE ic.invite_token = token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to anon and authenticated users
GRANT EXECUTE ON FUNCTION get_invite_details(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION is_invite_valid(TEXT) TO anon, authenticated;

-- ============================================================================
-- STEP 3: Update view if it exists
-- ============================================================================
-- The active_invites view may also reference old column names

DROP VIEW IF EXISTS active_invites;

CREATE OR REPLACE VIEW active_invites AS
SELECT
  ic.id,
  ic.wedding_id,
  ic.invite_token,
  ic.role,
  ic.wedding_profile_permissions,
  ic.created_by,
  ic.created_at,
  ic.is_used,
  ic.used_by,
  ic.used_at,
  wp.partner1_name,
  wp.partner2_name,
  u.email AS creator_email
FROM invite_codes ic
JOIN wedding_profiles wp ON ic.wedding_id = wp.id
LEFT JOIN auth.users u ON ic.created_by = u.id
WHERE (ic.is_used = false OR ic.is_used IS NULL);

-- Grant access to view
GRANT SELECT ON active_invites TO authenticated;

-- ============================================================================
-- STEP 4: Update cleanup function
-- ============================================================================
-- Remove reference to expires_at since we're using one-time use only

DROP FUNCTION IF EXISTS cleanup_expired_invites();

CREATE OR REPLACE FUNCTION cleanup_old_used_invites()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  -- Delete used invites older than 90 days (keep for audit trail)
  DELETE FROM invite_codes
  WHERE used_at < NOW() - INTERVAL '90 days'
    AND is_used = true;

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VERIFICATION QUERIES (commented out - uncomment to test)
-- ============================================================================

/*
-- Test the functions
SELECT is_invite_valid('test-token-123');
SELECT * FROM get_invite_details('test-token-123');
SELECT * FROM active_invites;

-- Check function definitions
\df is_invite_valid
\df get_invite_details
\df cleanup_old_used_invites
*/

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Summary of changes:
-- ✅ Fixed is_invite_valid() to use is_used instead of used
-- ✅ Fixed get_invite_details() to use is_used instead of used
-- ✅ Removed expires_at checks (one-time use only, no time expiration)
-- ✅ Updated active_invites view to use is_used
-- ✅ Created cleanup_old_used_invites() to replace cleanup_expired_invites()
-- ✅ Granted proper permissions to anon and authenticated users

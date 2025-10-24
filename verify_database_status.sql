-- ============================================================================
-- DATABASE STATUS VERIFICATION SCRIPT
-- ============================================================================
-- Run this in Supabase SQL Editor to see what's already deployed
-- ============================================================================

-- ============================================================================
-- 1. CHECK WHICH TABLES EXIST
-- ============================================================================
SELECT
    '1. TABLES STATUS' as check_category,
    expected.tablename,
    CASE
        WHEN pg_tables.rowsecurity THEN '✓ RLS Enabled'
        WHEN pg_tables.tablename IS NOT NULL THEN '✗ RLS DISABLED - SECURITY RISK!'
        ELSE '✗ Missing'
    END as rls_status,
    CASE
        WHEN pg_tables.tablename IS NOT NULL THEN '✓ Exists'
        ELSE '✗ Missing'
    END as exists_status
FROM (
    VALUES
        ('wedding_profiles'),
        ('wedding_members'),
        ('profiles'),
        ('chat_messages'),
        ('pending_updates'),
        ('invite_codes')
) AS expected(tablename)
LEFT JOIN pg_tables ON pg_tables.tablename = expected.tablename
    AND pg_tables.schemaname = 'public'
ORDER BY expected.tablename;

-- Expected: All 6 tables exist with RLS Enabled

-- ============================================================================
-- 2. POLICY COUNT BY TABLE
-- ============================================================================
SELECT
    '2. POLICY COUNTS' as check_category,
    tablename,
    COUNT(*) as policy_count,
    CASE
        WHEN tablename = 'wedding_profiles' AND COUNT(*) = 4 THEN '✓'
        WHEN tablename = 'wedding_members' AND COUNT(*) = 5 THEN '✓'
        WHEN tablename = 'chat_messages' AND COUNT(*) = 3 THEN '✓'
        WHEN tablename = 'pending_updates' AND COUNT(*) = 4 THEN '✓'
        WHEN tablename = 'invite_codes' AND COUNT(*) = 3 THEN '✓'
        WHEN tablename = 'profiles' AND COUNT(*) = 5 THEN '✓'
        ELSE '✗ Wrong count'
    END as status
FROM pg_policies
WHERE tablename IN (
  'wedding_profiles',
  'wedding_members',
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
)
GROUP BY tablename
ORDER BY tablename;

-- Expected:
-- wedding_profiles: 4 policies ✓
-- wedding_members: 5 policies ✓
-- chat_messages: 3 policies ✓
-- pending_updates: 4 policies ✓
-- invite_codes: 3 policies ✓
-- profiles: 5 policies ✓

-- ============================================================================
-- 3. TOTAL POLICY COUNT
-- ============================================================================
SELECT
    '3. TOTAL POLICIES' as check_category,
    COUNT(*) as total_policies,
    CASE
        WHEN COUNT(*) = 24 THEN '✓ Correct (24 policies)'
        WHEN COUNT(*) < 24 THEN '✗ Missing policies - need to run migrations'
        ELSE '⚠ More than expected - may have duplicates'
    END as status
FROM pg_policies
WHERE tablename IN (
  'wedding_profiles',
  'wedding_members',
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
);

-- Expected: 24 total policies

-- ============================================================================
-- 4. CHECK FOR BUGGY STATUS COLUMN REFERENCES
-- ============================================================================
-- This checks if any policies reference the non-existent 'status' column
SELECT
    '4. BUGGY POLICIES CHECK' as check_category,
    tablename,
    policyname,
    '✗ BUGGY - References non-existent status column' as status
FROM pg_policies
WHERE tablename IN ('wedding_profiles', 'wedding_members')
  AND (
    pg_get_expr(qual, (tablename)::regclass) LIKE '%status%'
    OR pg_get_expr(with_check, (tablename)::regclass) LIKE '%status%'
  );

-- Expected: No rows returned (if rows appear, you have buggy policies)

-- ============================================================================
-- 5. CHECK TRIGGERS
-- ============================================================================
SELECT
    '5. TRIGGERS' as check_category,
    trigger_name,
    event_object_table as table_name,
    CASE
        WHEN trigger_name = 'on_auth_user_created' THEN '✓ Profile auto-creation'
        WHEN trigger_name LIKE 'update_%_updated_at' THEN '✓ Timestamp update'
        ELSE 'Unknown trigger'
    END as purpose
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table IN ('profiles', 'pending_updates')
ORDER BY event_object_table, trigger_name;

-- Expected:
-- update_profiles_updated_at on profiles
-- update_pending_updates_updated_at on pending_updates
-- Also check: on_auth_user_created on auth.users (may not show in this query)

-- ============================================================================
-- 6. CHECK BESTIE ROLE SUPPORT
-- ============================================================================
SELECT
    '6. BESTIE ROLE SUPPORT' as check_category,
    tc.table_name,
    tc.constraint_name,
    cc.check_clause,
    CASE
        WHEN tc.table_name = 'wedding_members'
            AND cc.check_clause LIKE '%bestie%' THEN '✓ Bestie supported'
        WHEN tc.table_name = 'invite_codes'
            AND cc.check_clause LIKE '%bestie%' THEN '✓ Bestie supported'
        WHEN tc.table_name = 'chat_messages'
            AND cc.check_clause LIKE '%bestie%' THEN '✓ Bestie supported'
        ELSE '✗ Bestie NOT supported - run setup_bestie_functionality.sql'
    END as status
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name IN ('wedding_members', 'invite_codes', 'chat_messages')
  AND tc.constraint_type = 'CHECK'
  AND (tc.constraint_name LIKE '%role%' OR tc.constraint_name LIKE '%message_type%')
ORDER BY tc.table_name;

-- Expected:
-- wedding_members: role IN ('owner', 'member', 'bestie') ✓
-- invite_codes: role IN ('member', 'bestie') ✓
-- chat_messages: message_type IN ('main', 'bestie') ✓

-- ============================================================================
-- 7. CHECK INVITE_CODES ROLE COLUMN
-- ============================================================================
SELECT
    '7. INVITE_CODES ROLE COLUMN' as check_category,
    column_name,
    data_type,
    column_default,
    CASE
        WHEN column_name = 'role' THEN '✓ Role column exists'
        ELSE '✗ Missing'
    END as status
FROM information_schema.columns
WHERE table_name = 'invite_codes'
  AND column_name = 'role';

-- Expected: 1 row showing role column with default 'member'

-- ============================================================================
-- 8. LIST ALL POLICIES (DETAILED)
-- ============================================================================
SELECT
    '8. POLICY DETAILS' as check_category,
    tablename,
    policyname,
    cmd as operation,
    roles,
    CASE
        WHEN cmd = 'SELECT' THEN 'Read access'
        WHEN cmd = 'INSERT' THEN 'Create access'
        WHEN cmd = 'UPDATE' THEN 'Modify access'
        WHEN cmd = 'DELETE' THEN 'Delete access'
        WHEN cmd = 'ALL' THEN 'Full access (service role)'
        ELSE 'Unknown'
    END as description
FROM pg_policies
WHERE tablename IN (
  'wedding_profiles',
  'wedding_members',
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
)
ORDER BY tablename, cmd, policyname;

-- This gives you a complete list of all active policies

-- ============================================================================
-- 9. CHECK FOR MISSING TABLES
-- ============================================================================
SELECT
    '9. MISSING TABLES' as check_category,
    expected_table,
    '✗ MISSING - Run create_missing_tables.sql' as status
FROM (
    VALUES
        ('wedding_profiles'),
        ('wedding_members'),
        ('profiles'),
        ('chat_messages'),
        ('pending_updates'),
        ('invite_codes')
) AS expected(expected_table)
WHERE NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename = expected.expected_table
);

-- Expected: No rows returned (if rows appear, those tables are missing)

-- ============================================================================
-- 10. DEPLOYMENT STATUS SUMMARY
-- ============================================================================
WITH
    table_status AS (
        SELECT COUNT(*) as existing_tables
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename IN (
            'wedding_profiles', 'wedding_members', 'profiles',
            'chat_messages', 'pending_updates', 'invite_codes'
          )
    ),
    rls_status AS (
        SELECT COUNT(*) as rls_enabled_tables
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename IN (
            'wedding_profiles', 'wedding_members', 'profiles',
            'chat_messages', 'pending_updates', 'invite_codes'
          )
          AND rowsecurity = true
    ),
    policy_status AS (
        SELECT COUNT(*) as total_policies
        FROM pg_policies
        WHERE tablename IN (
          'wedding_profiles', 'wedding_members', 'chat_messages',
          'pending_updates', 'invite_codes', 'profiles'
        )
    ),
    bestie_status AS (
        SELECT COUNT(*) as bestie_constraints
        FROM information_schema.check_constraints
        WHERE check_clause LIKE '%bestie%'
          AND constraint_name IN (
            SELECT constraint_name
            FROM information_schema.table_constraints
            WHERE table_name IN ('wedding_members', 'invite_codes', 'chat_messages')
          )
    )
SELECT
    '10. DEPLOYMENT STATUS SUMMARY' as check_category,
    ts.existing_tables || '/6' as tables_created,
    rs.rls_enabled_tables || '/6' as tables_secured,
    ps.total_policies || '/24' as policies_active,
    bs.bestie_constraints || '/3' as bestie_ready,
    CASE
        WHEN ts.existing_tables = 6
            AND rs.rls_enabled_tables = 6
            AND ps.total_policies = 24
            AND bs.bestie_constraints >= 2 THEN '✓ FULLY DEPLOYED'
        WHEN ts.existing_tables < 6 THEN '✗ TABLES MISSING - Run create_missing_tables.sql'
        WHEN rs.rls_enabled_tables < 6 THEN '✗ RLS MISSING - Run RLS migration files'
        WHEN ps.total_policies < 24 THEN '✗ POLICIES INCOMPLETE - Run RLS migration files'
        WHEN bs.bestie_constraints < 2 THEN '⚠ BESTIE NOT READY - Run setup_bestie_functionality.sql'
        ELSE '⚠ PARTIAL DEPLOYMENT'
    END as overall_status
FROM table_status ts, rls_status rs, policy_status ps, bestie_status bs;

-- ============================================================================
-- INTERPRETATION GUIDE
-- ============================================================================
/*

STATUS MEANINGS:

✓ = Working correctly
✗ = Missing or broken (action required)
⚠ = Warning (may need attention)

WHAT TO DO BASED ON RESULTS:

1. If "TABLES MISSING":
   → Run create_missing_tables.sql

2. If "RLS MISSING" or "POLICIES INCOMPLETE":
   → Run rls_critical_tables_fixed.sql
   → Then run rls_remaining_tables.sql

3. If "BESTIE NOT READY":
   → Run setup_bestie_functionality.sql

4. If "BUGGY POLICIES" found (section 4):
   → Run rls_critical_tables_fixed.sql to replace them

5. If "FULLY DEPLOYED":
   → You're ready to test the application!
   → Next step: Deploy Supabase Edge Functions

*/

-- ============================================================================
-- END OF VERIFICATION
-- ============================================================================

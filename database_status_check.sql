-- ============================================================================
-- DATABASE STATUS CHECK (MERGED VERSION)
-- ============================================================================
-- Combines check_database_status.sql + verify_database_status.sql
-- Run this in Supabase SQL Editor to verify deployment status
-- ============================================================================
-- MODES:
--   Quick Mode: Run checks 1-6 (essential verification)
--   Full Mode: Run all checks 1-10 (comprehensive analysis)
-- ============================================================================

-- ============================================================================
-- CHECK 1: ALL TABLES EXIST WITH RLS ENABLED
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
-- CHECK 2: POLICY COUNT PER TABLE
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
-- chat_messages    | 3  | ✓
-- invite_codes     | 3  | ✓
-- pending_updates  | 4  | ✓
-- profiles         | 5  | ✓
-- wedding_members  | 5  | ✓
-- wedding_profiles | 4  | ✓

-- ============================================================================
-- CHECK 3: TOTAL POLICY COUNT
-- ============================================================================
SELECT
    '3. TOTAL POLICIES' as check_category,
    COUNT(*) as total_policies,
    CASE
        WHEN COUNT(*) = 24 THEN '✓ Complete (24 policies)'
        WHEN COUNT(*) < 24 THEN '✗ Incomplete - ' || (24 - COUNT(*))::text || ' policies missing'
        ELSE '⚠ Too many (' || (COUNT(*) - 24)::text || ' extra)'
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

-- Expected: 24 | ✓ Complete (24 policies)

-- ============================================================================
-- CHECK 4: BUGGY POLICIES (status column bug)
-- ============================================================================
SELECT
    '4. BUGGY POLICIES CHECK' as check_category,
    tablename,
    policyname,
    '✗ BUGGY - has status column reference' as issue
FROM pg_policies
WHERE tablename IN ('wedding_profiles', 'wedding_members')
  AND (
    qual::text LIKE '%status%'
    OR with_check::text LIKE '%status%'
  );

-- Expected: 0 rows (no buggy policies)
-- If rows appear, re-run rls_critical_tables_fixed.sql

-- ============================================================================
-- CHECK 5: BESTIE ROLE SUPPORT
-- ============================================================================
SELECT
    '5. BESTIE ROLE SUPPORT' as check_category,
    tc.table_name,
    CASE
        WHEN tc.table_name = 'wedding_members'
            AND cc.check_clause LIKE '%bestie%' THEN '✓ Bestie role supported'
        WHEN tc.table_name = 'invite_codes'
            AND cc.check_clause LIKE '%bestie%' THEN '✓ Bestie role supported'
        WHEN tc.table_name = 'chat_messages'
            AND cc.check_clause LIKE '%bestie%' THEN '✓ Bestie message_type supported'
        ELSE '✗ Bestie NOT supported'
    END as status
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name IN ('wedding_members', 'invite_codes', 'chat_messages')
  AND tc.constraint_type = 'CHECK'
  AND (tc.constraint_name LIKE '%role%' OR tc.constraint_name LIKE '%message_type%')
ORDER BY tc.table_name;

-- Expected: 3 rows with ✓ status
-- If missing, run migrations/001-006

-- ============================================================================
-- CHECK 6: DEPLOYMENT STATUS SUMMARY
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
    '6. DEPLOYMENT STATUS SUMMARY' as check_category,
    ts.existing_tables || '/6' as tables_created,
    rs.rls_enabled_tables || '/6' as tables_secured,
    ps.total_policies || '/24' as policies_active,
    bs.bestie_constraints || '/3' as bestie_ready,
    CASE
        WHEN ts.existing_tables = 6
            AND rs.rls_enabled_tables = 6
            AND ps.total_policies = 24
            AND bs.bestie_constraints >= 2 THEN '✓✓✓ FULLY DEPLOYED'
        WHEN ts.existing_tables < 6 THEN '✗ TABLES MISSING - Run create_missing_tables.sql'
        WHEN rs.rls_enabled_tables < 6 THEN '✗ RLS MISSING - Run RLS migration files'
        WHEN ps.total_policies < 24 THEN '✗ POLICIES INCOMPLETE - Run RLS migration files'
        WHEN bs.bestie_constraints < 2 THEN '⚠ BESTIE NOT READY - Run migrations/001-006'
        ELSE '⚠ PARTIAL DEPLOYMENT'
    END as overall_status
FROM table_status ts, rls_status rs, policy_status ps, bestie_status bs;

-- ============================================================================
-- QUICK MODE ENDS HERE
-- For quick verification, stop here. For comprehensive analysis, continue.
-- ============================================================================

-- ============================================================================
-- CHECK 7: TRIGGERS (FULL MODE)
-- ============================================================================
SELECT
    '7. TRIGGERS' as check_category,
    trigger_name,
    event_object_table as table_name,
    CASE
        WHEN trigger_name = 'on_auth_user_created' THEN '✓ Profile auto-creation'
        WHEN trigger_name LIKE 'update_%_updated_at' THEN '✓ Timestamp update'
        WHEN trigger_name LIKE 'trigger_update_%' THEN '✓ Timestamp update'
        ELSE 'Unknown trigger'
    END as purpose
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table IN ('profiles', 'pending_updates', 'bestie_permissions', 'bestie_knowledge')
ORDER BY event_object_table, trigger_name;

-- Expected:
-- update_profiles_updated_at on profiles
-- update_pending_updates_updated_at on pending_updates
-- trigger_update_bestie_permissions_updated_at on bestie_permissions
-- trigger_update_bestie_knowledge_updated_at on bestie_knowledge

-- ============================================================================
-- CHECK 8: BESTIE ADVANCED TABLES (FULL MODE)
-- ============================================================================
SELECT
    '8. BESTIE ADVANCED TABLES' as check_category,
    tablename,
    CASE
        WHEN tablename = 'bestie_permissions' THEN '✓ Permissions table exists'
        WHEN tablename = 'bestie_knowledge' THEN '✓ Knowledge table exists'
        ELSE '✗ Missing'
    END as status
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('bestie_permissions', 'bestie_knowledge')
ORDER BY tablename;

-- Expected: 2 rows (both tables exist)
-- If missing, run migrations/002-003

-- ============================================================================
-- CHECK 9: POLICY DETAILS (FULL MODE)
-- ============================================================================
SELECT
    '9. POLICY DETAILS' as check_category,
    tablename,
    policyname,
    cmd as operation,
    CASE
        WHEN cmd = 'SELECT' THEN 'Read access'
        WHEN cmd = 'INSERT' THEN 'Create access'
        WHEN cmd = 'UPDATE' THEN 'Modify access'
        WHEN cmd = 'DELETE' THEN 'Delete access'
        WHEN cmd = 'ALL' THEN 'Full access (service role)'
        ELSE 'Unknown'
    END as description,
    roles
FROM pg_policies
WHERE tablename IN (
  'wedding_profiles',
  'wedding_members',
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles',
  'bestie_permissions',
  'bestie_knowledge'
)
ORDER BY tablename, cmd, policyname;

-- This gives you a complete list of all active policies

-- ============================================================================
-- CHECK 10: MISSING TABLES (FULL MODE)
-- ============================================================================
SELECT
    '10. MISSING TABLES' as check_category,
    expected_table,
    '✗ MISSING - Run database_init.sql' as status
FROM (
    VALUES
        ('wedding_profiles'),
        ('wedding_members'),
        ('profiles'),
        ('chat_messages'),
        ('pending_updates'),
        ('invite_codes'),
        ('bestie_permissions'),
        ('bestie_knowledge')
) AS expected(expected_table)
WHERE NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename = expected.expected_table
);

-- Expected: No rows returned (if rows appear, those tables are missing)

-- ============================================================================
-- INTERPRETATION GUIDE
-- ============================================================================
/*
WHAT THE RESULTS MEAN:

CHECK 1: TABLES STATUS
✓ All 6 core tables exist with RLS enabled → Good
✗ RLS DISABLED → CRITICAL SECURITY RISK! Enable RLS immediately
✗ Missing → Run create_missing_tables.sql

CHECK 2: POLICY COUNTS
✓ All correct counts → Policies properly configured
✗ Wrong count → Re-run corresponding RLS migration file

CHECK 3: TOTAL POLICIES
✓ 24 policies → Core system fully secured
< 24 policies → Run missing RLS migration files
> 24 policies → May have duplicate policies

CHECK 4: BUGGY POLICIES
0 rows → No bugs detected
Rows appear → You have status column bug, run rls_critical_tables_fixed.sql

CHECK 5: BESTIE ROLE SUPPORT
3 rows with ✓ → Bestie functionality configured
Missing → Run migrations/001-006

CHECK 6: DEPLOYMENT STATUS SUMMARY
✓✓✓ FULLY DEPLOYED → System ready for production
✗ TABLES MISSING → Run create_missing_tables.sql
✗ RLS MISSING → Run rls_critical_tables_fixed.sql + rls_remaining_tables.sql
✗ POLICIES INCOMPLETE → Re-run RLS migration files
⚠ BESTIE NOT READY → Run migrations/001-006

FULL MODE CHECKS (7-10):
CHECK 7: Verifies auto-update triggers are in place
CHECK 8: Confirms advanced bestie tables exist
CHECK 9: Lists all policies with descriptions
CHECK 10: Identifies any missing tables from full schema

DEPLOYMENT ORDER (if starting fresh):
1. create_missing_tables.sql
2. rls_critical_tables_fixed.sql
3. rls_remaining_tables.sql
4. migrations/001_add_invited_by_to_wedding_members.sql
5. migrations/002_create_bestie_permissions_table.sql
6. migrations/003_create_bestie_knowledge_table.sql
7. migrations/004_rls_bestie_permissions.sql
8. migrations/005_rls_bestie_knowledge.sql
9. migrations/006_unified_invite_system.sql

Or simply run: database_init.sql (executes all in correct order)
*/

-- ============================================================================
-- QUICK TROUBLESHOOTING
-- ============================================================================
/*
SYMPTOM: "Permission denied" errors in app
→ Run CHECK 1-3 to verify RLS is enabled and policies exist

SYMPTOM: Users see data they shouldn't
→ Run CHECK 4 to check for buggy policies with status column bug

SYMPTOM: Bestie features not working
→ Run CHECK 5 and CHECK 8 to verify bestie support

SYMPTOM: Database feels incomplete
→ Run CHECK 6 for overall status summary

SYMPTOM: Need detailed policy breakdown
→ Run CHECK 9 (Full Mode) to see all policies
*/

-- ============================================================================
-- END OF STATUS CHECK
-- ============================================================================

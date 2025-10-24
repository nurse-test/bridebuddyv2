-- ============================================================================
-- SIMPLE DATABASE STATUS CHECK
-- ============================================================================
-- Run this in Supabase SQL Editor to quickly verify deployment status
-- ============================================================================

-- ============================================================================
-- 1. CHECK ALL 6 TABLES EXIST WITH RLS
-- ============================================================================
SELECT
    tablename,
    CASE WHEN rowsecurity THEN '✓ RLS Enabled' ELSE '✗ RLS OFF' END as rls
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'wedding_profiles',
    'wedding_members',
    'profiles',
    'chat_messages',
    'pending_updates',
    'invite_codes'
  )
ORDER BY tablename;

-- Expected: 6 rows, all with "✓ RLS Enabled"

-- ============================================================================
-- 2. COUNT POLICIES PER TABLE
-- ============================================================================
SELECT
    tablename,
    COUNT(*) as policies,
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
-- 3. TOTAL POLICY COUNT
-- ============================================================================
SELECT
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
-- 4. CHECK FOR BUGGY POLICIES (status column)
-- ============================================================================
SELECT
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
-- 5. CHECK BESTIE ROLE SUPPORT
-- ============================================================================
SELECT
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
-- If missing, run setup_bestie_functionality.sql

-- ============================================================================
-- 6. DEPLOYMENT STATUS SUMMARY
-- ============================================================================
SELECT
    (SELECT COUNT(*) FROM pg_tables
     WHERE schemaname = 'public'
       AND tablename IN ('wedding_profiles', 'wedding_members', 'profiles',
                         'chat_messages', 'pending_updates', 'invite_codes')
    ) || '/6' as tables,

    (SELECT COUNT(*) FROM pg_tables
     WHERE schemaname = 'public'
       AND tablename IN ('wedding_profiles', 'wedding_members', 'profiles',
                         'chat_messages', 'pending_updates', 'invite_codes')
       AND rowsecurity = true
    ) || '/6' as rls_enabled,

    (SELECT COUNT(*) FROM pg_policies
     WHERE tablename IN ('wedding_profiles', 'wedding_members', 'chat_messages',
                         'pending_updates', 'invite_codes', 'profiles')
    ) || '/24' as policies,

    CASE
        WHEN (SELECT COUNT(*) FROM pg_tables
              WHERE schemaname = 'public'
                AND tablename IN ('wedding_profiles', 'wedding_members', 'profiles',
                                  'chat_messages', 'pending_updates', 'invite_codes')) = 6
            AND (SELECT COUNT(*) FROM pg_tables
                 WHERE schemaname = 'public'
                   AND tablename IN ('wedding_profiles', 'wedding_members', 'profiles',
                                     'chat_messages', 'pending_updates', 'invite_codes')
                   AND rowsecurity = true) = 6
            AND (SELECT COUNT(*) FROM pg_policies
                 WHERE tablename IN ('wedding_profiles', 'wedding_members', 'chat_messages',
                                     'pending_updates', 'invite_codes', 'profiles')) = 24
        THEN '✓✓✓ FULLY DEPLOYED'
        WHEN (SELECT COUNT(*) FROM pg_tables
              WHERE schemaname = 'public'
                AND tablename IN ('wedding_profiles', 'wedding_members', 'profiles',
                                  'chat_messages', 'pending_updates', 'invite_codes')) < 6
        THEN '✗ TABLES MISSING - Run create_missing_tables.sql'
        WHEN (SELECT COUNT(*) FROM pg_policies
              WHERE tablename IN ('wedding_profiles', 'wedding_members', 'chat_messages',
                                  'pending_updates', 'invite_codes', 'profiles')) < 24
        THEN '✗ POLICIES INCOMPLETE - Run RLS migration files'
        ELSE '⚠ PARTIAL DEPLOYMENT'
    END as status;

-- ============================================================================
-- INTERPRETATION
-- ============================================================================
/*
WHAT THE RESULTS MEAN:

1. TABLES: Should show 6/6 with all RLS Enabled
   - If less than 6: Run create_missing_tables.sql

2. POLICIES: Should show correct counts per table
   - If any show ✗: Re-run the corresponding RLS migration file

3. TOTAL: Should be 24 policies
   - 0-9: Only critical tables secured, run rls_remaining_tables.sql
   - 10-23: Partial deployment, re-run missing files
   - 24: ✓ Complete

4. BUGGY POLICIES: Should be empty
   - If rows appear: You have the status column bug, run rls_critical_tables_fixed.sql

5. BESTIE SUPPORT: Should show 3 rows with ✓
   - If missing: Run setup_bestie_functionality.sql

6. SUMMARY: Should show "✓✓✓ FULLY DEPLOYED"
   - Follow the instructions if not

DEPLOYMENT ORDER:
1. create_missing_tables.sql
2. rls_critical_tables_fixed.sql
3. rls_remaining_tables.sql
4. setup_bestie_functionality.sql
*/

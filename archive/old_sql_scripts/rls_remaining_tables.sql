-- ============================================================================
-- BRIDE BUDDY - RLS POLICIES FOR REMAINING TABLES
-- ============================================================================
-- Secures the remaining 4 tables: chat_messages, pending_updates,
-- invite_codes, and profiles
-- Run in Supabase Dashboard → SQL Editor
-- Safe to run multiple times
-- ============================================================================

-- ============================================================================
-- TABLE 1: chat_messages
-- ============================================================================
-- Stores AI chat conversation history
-- Security: Users can only see their OWN messages for their wedding(s)

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Clean slate
DROP POLICY IF EXISTS "Users can view own chat messages" ON chat_messages;
DROP POLICY IF EXISTS "Backend can insert messages" ON chat_messages;
DROP POLICY IF EXISTS "Backend full access" ON chat_messages;

-- POLICY 1: Users can SELECT their own messages for their wedding(s)
-- Double protection: Must be YOUR message AND for YOUR wedding
CREATE POLICY "Users can view own chat messages"
ON chat_messages FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  AND wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

-- POLICY 2: Only backend can INSERT (AI creates messages)
CREATE POLICY "Backend can insert messages"
ON chat_messages FOR INSERT
TO service_role
WITH CHECK (true);

-- POLICY 3: Backend has full access
CREATE POLICY "Backend full access"
ON chat_messages FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- TABLE 2: pending_updates
-- ============================================================================
-- Wedding profile updates awaiting approval
-- Security: Users see updates for their wedding, owners can approve/reject

ALTER TABLE pending_updates ENABLE ROW LEVEL SECURITY;

-- Clean slate
DROP POLICY IF EXISTS "Users can view wedding updates" ON pending_updates;
DROP POLICY IF EXISTS "Owners can approve/reject updates" ON pending_updates;
DROP POLICY IF EXISTS "Backend can create updates" ON pending_updates;
DROP POLICY IF EXISTS "Backend full access" ON pending_updates;

-- POLICY 1: Users can SELECT updates for their wedding(s)
CREATE POLICY "Users can view wedding updates"
ON pending_updates FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

-- POLICY 2: Wedding owners can UPDATE (approve/reject)
CREATE POLICY "Owners can approve/reject updates"
ON pending_updates FOR UPDATE
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role = 'owner'
  )
)
WITH CHECK (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role = 'owner'
  )
);

-- POLICY 3: Backend can INSERT (AI creates pending updates)
CREATE POLICY "Backend can create updates"
ON pending_updates FOR INSERT
TO service_role
WITH CHECK (true);

-- POLICY 4: Backend has full access
CREATE POLICY "Backend full access"
ON pending_updates FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- TABLE 3: invite_codes
-- ============================================================================
-- Wedding invitation codes
-- Security: Users see invites for their wedding(s), members can create

ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- Clean slate
DROP POLICY IF EXISTS "Users can view wedding invites" ON invite_codes;
DROP POLICY IF EXISTS "Members can create invites" ON invite_codes;
DROP POLICY IF EXISTS "Backend full access" ON invite_codes;

-- POLICY 1: Users can SELECT invites for their wedding(s)
CREATE POLICY "Users can view wedding invites"
ON invite_codes FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

-- POLICY 2: Wedding members can INSERT invites
CREATE POLICY "Members can create invites"
ON invite_codes FOR INSERT
TO authenticated
WITH CHECK (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

-- POLICY 3: Backend has full access (for marking invites as used)
CREATE POLICY "Backend full access"
ON invite_codes FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- TABLE 4: profiles
-- ============================================================================
-- User profile data (linked to auth.users)
-- Security: Users see own profile + profiles of wedding co-members

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Clean slate
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view co-member profiles" ON profiles;
DROP POLICY IF EXISTS "Users can create own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Backend full access" ON profiles;

-- POLICY 1: Users can SELECT their own profile
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
TO authenticated
USING (id = auth.uid());

-- POLICY 2: Users can SELECT profiles of wedding co-members
-- If you're in a wedding with someone, you can see their profile
CREATE POLICY "Users can view co-member profiles"
ON profiles FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT DISTINCT user_id
    FROM wedding_members
    WHERE wedding_id IN (
      SELECT wedding_id
      FROM wedding_members
      WHERE user_id = auth.uid()
    )
  )
);

-- POLICY 3: Users can INSERT their own profile (on signup)
CREATE POLICY "Users can create own profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- POLICY 4: Users can UPDATE their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- POLICY 5: Backend has full access
CREATE POLICY "Backend full access"
ON profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Step 1: Verify RLS is enabled on all 4 tables
SELECT
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename IN (
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
)
ORDER BY tablename;
-- Expected: rowsecurity = true for all 4 tables

-- Step 2: Count policies per table
SELECT
  tablename,
  COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN (
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
)
GROUP BY tablename
ORDER BY tablename;
-- Expected counts:
-- chat_messages: 3 policies
-- invite_codes: 3 policies
-- pending_updates: 4 policies
-- profiles: 5 policies

-- Step 3: List all policies with details
SELECT
  tablename,
  policyname,
  cmd as operation,
  roles
FROM pg_policies
WHERE tablename IN (
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
)
ORDER BY tablename, policyname;

-- Step 4: Verify TOTAL policy count across all 6 tables
SELECT
  COUNT(*) as total_policies
FROM pg_policies
WHERE tablename IN (
  'wedding_profiles',
  'wedding_members',
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
);
-- Expected: 24 total policies (4+5+3+4+3+5)

-- ============================================================================
-- TESTING GUIDE (EXAMPLES - DO NOT RUN AUTOMATICALLY)
-- ============================================================================
-- These are example queries to run manually after deployment.
-- They are commented out to prevent errors during migration.
-- ============================================================================

/*
-- Test 1: Can you see your chat messages?
SELECT * FROM chat_messages;
-- Should return: Only YOUR messages for YOUR wedding(s)

-- Test 2: Can you see your wedding's invites?
SELECT * FROM invite_codes;
-- Should return: Invites for weddings you're a member of

-- Test 3: Can you see co-member profiles?
SELECT * FROM profiles;
-- Should return: Your profile + profiles of people in your wedding(s)

-- Test 4: Can you see pending updates?
SELECT * FROM pending_updates;
-- Should return: Updates for your wedding(s)

-- Test 5: Try to query someone else's data
-- Replace 'other-wedding-id' with an actual wedding ID you don't belong to
-- SELECT * FROM chat_messages WHERE wedding_id = 'other-wedding-id';
-- Should return: 0 rows (no access)
*/

-- ============================================================================
-- SECURITY SUMMARY
-- ============================================================================

/*
ALL 6 TABLES NOW SECURED:

✅ wedding_profiles (4 policies)
   - Users see only their weddings
   - Only owners can update

✅ wedding_members (5 policies)
   - Users see members of their weddings
   - Self-join for creating/joining
   - Owners can manage members

✅ chat_messages (3 policies)
   - Users see ONLY their own messages
   - Backend creates messages

✅ pending_updates (4 policies)
   - Users see updates for their weddings
   - Only owners can approve/reject
   - Backend creates updates

✅ invite_codes (3 policies)
   - Users see invites for their weddings
   - Members can create invites
   - Backend marks as used

✅ profiles (5 policies)
   - Users see own profile
   - Users see co-member profiles
   - Users manage own profile only

TOTAL: 24 policies protecting all sensitive data
*/

-- ============================================================================
-- ROLLBACK (Emergency Only)
-- ============================================================================

-- If needed, disable RLS on remaining tables:
/*
ALTER TABLE chat_messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE pending_updates DISABLE ROW LEVEL SECURITY;
ALTER TABLE invite_codes DISABLE ROW LEVEL SECURITY;
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
*/

-- Re-enable when fixed:
/*
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
*/

-- ============================================================================
-- COMPLETE - ALL TABLES SECURED
-- ============================================================================
-- Your entire database is now protected with Row Level Security!
-- Users can only access data for weddings they're members of.
-- Backend maintains elevated access via service role.
-- ============================================================================

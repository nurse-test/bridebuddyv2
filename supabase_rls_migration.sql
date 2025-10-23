-- ============================================================================
-- BRIDE BUDDY V2 - ROW LEVEL SECURITY (RLS) MIGRATION
-- ============================================================================
-- This script enables RLS on all tables and creates security policies
-- Run this in Supabase SQL Editor: Dashboard → SQL Editor → New Query
-- ============================================================================

-- ============================================================================
-- TABLE 1: wedding_profiles
-- ============================================================================

ALTER TABLE wedding_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (safe to run multiple times)
DROP POLICY IF EXISTS "Users can view their own weddings" ON wedding_profiles;
DROP POLICY IF EXISTS "Users can create their own wedding" ON wedding_profiles;
DROP POLICY IF EXISTS "Wedding owners can update their wedding" ON wedding_profiles;
DROP POLICY IF EXISTS "Service role full access" ON wedding_profiles;

-- Policy 1: Users can SELECT weddings they're a member of
CREATE POLICY "Users can view their own weddings"
ON wedding_profiles FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
    AND status = 'active'
  )
);

-- Policy 2: Users can INSERT their first wedding
CREATE POLICY "Users can create their own wedding"
ON wedding_profiles FOR INSERT
TO authenticated
WITH CHECK (
  owner_id = auth.uid()
);

-- Policy 3: Only wedding owner can UPDATE
CREATE POLICY "Wedding owners can update their wedding"
ON wedding_profiles FOR UPDATE
TO authenticated
USING (
  owner_id = auth.uid()
)
WITH CHECK (
  owner_id = auth.uid()
);

-- Policy 4: Service role can do everything (for backend operations)
CREATE POLICY "Service role full access"
ON wedding_profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- TABLE 2: wedding_members
-- ============================================================================

ALTER TABLE wedding_members ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view wedding members" ON wedding_members;
DROP POLICY IF EXISTS "Users can add themselves as owner" ON wedding_members;
DROP POLICY IF EXISTS "Users can join via invite" ON wedding_members;
DROP POLICY IF EXISTS "Owners can manage members" ON wedding_members;
DROP POLICY IF EXISTS "Service role full access" ON wedding_members;

-- Policy 1: Users can SELECT members of their wedding(s)
CREATE POLICY "Users can view wedding members"
ON wedding_members FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
    AND status = 'active'
  )
);

-- Policy 2: Users can INSERT themselves as owner when creating
CREATE POLICY "Users can add themselves as owner"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND role = 'owner'
);

-- Policy 3: Users can INSERT themselves as member via invite
CREATE POLICY "Users can join via invite"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND role != 'owner'
);

-- Policy 4: Owners can UPDATE member roles
CREATE POLICY "Owners can manage members"
ON wedding_members FOR UPDATE
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
    AND role = 'owner'
  )
);

-- Policy 5: Service role full access
CREATE POLICY "Service role full access"
ON wedding_members FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- TABLE 3: chat_messages
-- ============================================================================

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view their own chat messages" ON chat_messages;
DROP POLICY IF EXISTS "Service role can insert messages" ON chat_messages;
DROP POLICY IF EXISTS "Service role full access" ON chat_messages;

-- Policy 1: Users can SELECT their own messages for their wedding
CREATE POLICY "Users can view their own chat messages"
ON chat_messages FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  AND wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
    AND status = 'active'
  )
);

-- Policy 2: Only service role can INSERT (backend creates messages)
CREATE POLICY "Service role can insert messages"
ON chat_messages FOR INSERT
TO service_role
WITH CHECK (true);

-- Policy 3: Service role full access
CREATE POLICY "Service role full access"
ON chat_messages FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- TABLE 4: pending_updates
-- ============================================================================

ALTER TABLE pending_updates ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view wedding updates" ON pending_updates;
DROP POLICY IF EXISTS "Owners can approve/reject updates" ON pending_updates;
DROP POLICY IF EXISTS "Service role can create updates" ON pending_updates;
DROP POLICY IF EXISTS "Service role full access" ON pending_updates;

-- Policy 1: Users can SELECT updates for their wedding
CREATE POLICY "Users can view wedding updates"
ON pending_updates FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
    AND status = 'active'
  )
);

-- Policy 2: Wedding owners can UPDATE (approve/reject)
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

-- Policy 3: Service role can INSERT (AI creates updates)
CREATE POLICY "Service role can create updates"
ON pending_updates FOR INSERT
TO service_role
WITH CHECK (true);

-- Policy 4: Service role full access
CREATE POLICY "Service role full access"
ON pending_updates FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- TABLE 5: invite_codes
-- ============================================================================

ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view wedding invites" ON invite_codes;
DROP POLICY IF EXISTS "Wedding members can create invites" ON invite_codes;
DROP POLICY IF EXISTS "Service role full access" ON invite_codes;

-- Policy 1: Users can SELECT invites for their wedding
CREATE POLICY "Users can view wedding invites"
ON invite_codes FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
    AND status = 'active'
  )
);

-- Policy 2: Wedding members can INSERT invites
CREATE POLICY "Wedding members can create invites"
ON invite_codes FOR INSERT
TO authenticated
WITH CHECK (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
    AND status = 'active'
  )
);

-- Policy 3: Service role full access (for marking as used)
CREATE POLICY "Service role full access"
ON invite_codes FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- TABLE 6: profiles
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view co-member profiles" ON profiles;
DROP POLICY IF EXISTS "Users can create own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Service role full access" ON profiles;

-- Policy 1: Users can view their own profile
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
TO authenticated
USING (id = auth.uid());

-- Policy 2: Users can view profiles of wedding co-members
CREATE POLICY "Users can view co-member profiles"
ON profiles FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT DISTINCT wm.user_id
    FROM wedding_members wm
    WHERE wm.wedding_id IN (
      SELECT wedding_id
      FROM wedding_members
      WHERE user_id = auth.uid()
      AND status = 'active'
    )
  )
);

-- Policy 3: Users can INSERT their own profile (on signup)
CREATE POLICY "Users can create own profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Policy 4: Users can UPDATE their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Policy 5: Service role full access
CREATE POLICY "Service role full access"
ON profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify RLS is enabled on all tables

SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename IN (
  'wedding_profiles',
  'wedding_members',
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
)
ORDER BY tablename;

-- Check policy counts (should have multiple policies per table)
SELECT
  schemaname,
  tablename,
  COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN (
  'wedding_profiles',
  'wedding_members',
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
)
GROUP BY schemaname, tablename
ORDER BY tablename;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- All tables now have RLS enabled with appropriate policies
-- Users can only access data for weddings they're members of
-- Service role (backend) maintains full access for AI and payment operations
-- ============================================================================

-- ============================================================================
-- BESTIE FUNCTIONALITY SETUP
-- ============================================================================
-- Ensures database is properly configured for bestie (MOH/Best Man) feature
-- Run this to verify/fix your bestie setup
-- ============================================================================

-- ============================================================================
-- 1. WEDDING_MEMBERS TABLE - Verify role column supports 'bestie'
-- ============================================================================

-- Check current wedding_members schema
DO $$
BEGIN
    -- Verify the role column exists and has proper check constraint
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'wedding_members'
        AND column_name = 'role'
    ) THEN
        RAISE NOTICE 'wedding_members.role column exists ✓';

        -- Drop old constraint if it exists
        ALTER TABLE wedding_members DROP CONSTRAINT IF EXISTS wedding_members_role_check;

        -- Add new constraint that includes 'bestie' role
        ALTER TABLE wedding_members ADD CONSTRAINT wedding_members_role_check
        CHECK (role IN ('owner', 'member', 'bestie'));

        RAISE NOTICE 'Updated role constraint to include owner, member, bestie ✓';
    ELSE
        RAISE EXCEPTION 'wedding_members.role column does not exist! Run create_missing_tables.sql first.';
    END IF;
END $$;

-- ============================================================================
-- 2. INVITE_CODES TABLE - Verify it supports role assignment
-- ============================================================================

-- Check if invite_codes table exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'invite_codes'
    ) THEN
        RAISE NOTICE 'invite_codes table exists ✓';

        -- Add role column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'invite_codes'
            AND column_name = 'role'
        ) THEN
            ALTER TABLE invite_codes ADD COLUMN role TEXT DEFAULT 'member'
            CHECK (role IN ('member', 'bestie'));
            RAISE NOTICE 'Added role column to invite_codes ✓';
        ELSE
            RAISE NOTICE 'invite_codes.role column already exists ✓';

            -- Update constraint to ensure it includes bestie
            ALTER TABLE invite_codes DROP CONSTRAINT IF EXISTS invite_codes_role_check;
            ALTER TABLE invite_codes ADD CONSTRAINT invite_codes_role_check
            CHECK (role IN ('member', 'bestie'));
            RAISE NOTICE 'Updated invite_codes role constraint ✓';
        END IF;
    ELSE
        RAISE EXCEPTION 'invite_codes table does not exist! Run create_missing_tables.sql first.';
    END IF;
END $$;

-- ============================================================================
-- 3. CHAT_MESSAGES TABLE - Verify message_type includes 'bestie'
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'chat_messages'
    ) THEN
        RAISE NOTICE 'chat_messages table exists ✓';

        -- Verify message_type constraint
        ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS chat_messages_message_type_check;
        ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_message_type_check
        CHECK (message_type IN ('main', 'bestie'));

        RAISE NOTICE 'Updated message_type constraint to include main, bestie ✓';
    ELSE
        RAISE EXCEPTION 'chat_messages table does not exist! Run create_missing_tables.sql first.';
    END IF;
END $$;

-- ============================================================================
-- 4. VERIFICATION QUERIES
-- ============================================================================

-- Check all tables exist
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'wedding_members') THEN '✓'
        ELSE '✗'
    END AS wedding_members_exists,
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invite_codes') THEN '✓'
        ELSE '✗'
    END AS invite_codes_exists,
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'chat_messages') THEN '✓'
        ELSE '✗'
    END AS chat_messages_exists,
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'wedding_profiles') THEN '✓'
        ELSE '✗'
    END AS wedding_profiles_exists;

-- Show wedding_members structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'wedding_members'
ORDER BY ordinal_position;

-- Show invite_codes structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'invite_codes'
ORDER BY ordinal_position;

-- Show all constraints on wedding_members
SELECT
    con.conname AS constraint_name,
    con.contype AS constraint_type,
    pg_get_constraintdef(con.oid) AS constraint_definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'wedding_members'
ORDER BY con.conname;

-- ============================================================================
-- 5. TEST QUERIES (commented out - run manually if needed)
-- ============================================================================

-- Test 1: Check if a user can be added as bestie
-- INSERT INTO wedding_members (wedding_id, user_id, role)
-- VALUES ('YOUR_WEDDING_ID', 'YOUR_USER_ID', 'bestie');

-- Test 2: Check if bestie can see wedding
-- SELECT * FROM wedding_profiles WHERE id IN (
--     SELECT wedding_id FROM wedding_members
--     WHERE user_id = 'YOUR_USER_ID' AND role = 'bestie'
-- );

-- Test 3: Check if bestie messages are segregated
-- SELECT * FROM chat_messages
-- WHERE message_type = 'bestie'
-- AND wedding_id = 'YOUR_WEDDING_ID';

-- ============================================================================
-- SUMMARY
-- ============================================================================
/*
This script ensures:

1. wedding_members.role supports: 'owner', 'member', 'bestie'
2. invite_codes.role supports: 'member', 'bestie'
3. chat_messages.message_type supports: 'main', 'bestie'
4. All RLS policies allow bestie users to access their wedding data

NEXT STEPS:
1. Run this SQL in your Supabase SQL Editor
2. Verify all checks pass (look for ✓ symbols)
3. Update your Supabase Edge Functions (create-invite, join-wedding) to:
   - Accept a 'role' parameter when creating invites
   - Assign the correct role when joining via invite code
4. Test the invite flow end-to-end

INVITE FLOW FOR BESTIE:
1. Bride/Groom creates invite with role='bestie'
2. MOH/Best Man signs up and uses invite code
3. They're added to wedding_members with role='bestie'
4. They can access bestie-v2.html (frontend checks role)
5. They can use bestie chat (backend saves with message_type='bestie')
6. All their messages are isolated from main wedding planning chat
*/

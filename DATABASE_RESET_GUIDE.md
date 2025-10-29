# Database Reset Guide - Clean 3-Role System

This guide will help you **reset your Supabase database** and initialize it with the clean 3-role system (Owner, Partner, Bestie).

## ⚠️ WARNING

**This will DELETE ALL DATA in your database!** Only do this if:
- You don't have production data you need to keep
- You're in development/testing mode
- You've backed up anything important

## Step 1: Clear All Tables in Supabase

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Click on your project
3. Go to **SQL Editor** (left sidebar)
4. Run this script to drop all tables:

```sql
-- Drop all tables in correct order (respecting foreign keys)
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS pending_updates CASCADE;
DROP TABLE IF EXISTS bestie_knowledge CASCADE;
DROP TABLE IF EXISTS bestie_permissions CASCADE;
DROP TABLE IF EXISTS bestie_profile CASCADE;
DROP TABLE IF EXISTS wedding_tasks CASCADE;
DROP TABLE IF EXISTS budget_tracker CASCADE;
DROP TABLE IF EXISTS vendor_tracker CASCADE;
DROP TABLE IF EXISTS invite_codes CASCADE;
DROP TABLE IF EXISTS wedding_members CASCADE;
DROP TABLE IF EXISTS wedding_profiles CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Drop views
DROP VIEW IF EXISTS active_invites CASCADE;
DROP VIEW IF EXISTS wedding_member_roles CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_profiles_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_pending_updates_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_bestie_permissions_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_bestie_knowledge_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_bestie_profile_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_wedding_profiles_updated_at() CASCADE;
DROP FUNCTION IF EXISTS is_wedding_member(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS is_wedding_owner(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS is_invite_valid(TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_invite_details(TEXT) CASCADE;
DROP FUNCTION IF EXISTS cleanup_expired_invites() CASCADE;
DROP FUNCTION IF EXISTS check_bestie_limit() CASCADE;

SELECT '✓ All tables, views, and functions dropped' as status;
```

## Step 2: Initialize Database with Clean Schema

1. Stay in **SQL Editor**
2. Open a new query tab
3. Copy the **ENTIRE** contents of `database_init.sql` from this repository
4. Paste it into the SQL Editor
5. Click **Run**

The script will create:
- ✅ All tables with correct structure
- ✅ Role constraints: **'owner', 'partner', 'bestie' ONLY**
- ✅ invite_codes can only create 'partner' or 'bestie' invites
- ✅ wedding_members can only have 'owner', 'partner', or 'bestie' roles
- ✅ All RLS policies
- ✅ All helper functions and views
- ✅ Proper permissions for each role

## Step 3: Verify the Setup

Run this verification query in SQL Editor:

```sql
-- Verify tables exist
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Verify role constraints
SELECT
  conname as constraint_name,
  conrelid::regclass as table_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname LIKE '%role%check%';

-- Should show:
-- invite_codes_role_check: CHECK (role IN ('partner', 'bestie'))
-- wedding_members_role_check: CHECK (role IN ('owner', 'partner', 'bestie'))
```

## Step 4: Test the System

After reinitialization, test the invite system:

1. **Create a test wedding:**
   - Sign up a new user
   - Create a wedding profile
   - User automatically gets 'owner' role

2. **Create partner invite:**
   - Go to invite page
   - Click "Invite Partner"
   - Share the link with a second test account
   - Accept invite → User gets 'partner' role with full access

3. **Create bestie invite:**
   - Click "Invite Bestie"
   - Share link with a third test account
   - Accept invite → User gets 'bestie' role with view access

## Expected Role Structure

After reinitialization, your database will support:

| Role | Created Via | Max Per Wedding | Access Level |
|------|-------------|-----------------|--------------|
| **Owner** | Wedding creation | 1 | Full access (read + edit everything) |
| **Partner** | Partner invite | 1 | Full access (read + edit everything) |
| **Bestie** | Bestie invite | 2 | View access (read only, limited edit) |

## Troubleshooting

### If you see "relation already exists" errors:
- Run Step 1 (drop tables) again to make sure everything is cleared

### If you see "role check violation" errors:
- Make sure you're using the latest `database_init.sql` from this branch
- The file has been updated with correct role constraints

### If you still have issues:
- Check Supabase logs in Dashboard → Logs
- Verify you're running as the project owner (not read-only user)

## What Changed?

The clean 3-role system removes:
- ❌ 'co_planner' role (replaced with 'bestie')
- ❌ 'member' role (replaced with 'bestie')
- ❌ 'team member' references in UI
- ✅ Clean, simple role system: Owner, Partner, Bestie

All frontend and API code has been updated to work with this new structure.

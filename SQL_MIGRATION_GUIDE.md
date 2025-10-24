# 🗄️ SQL MIGRATION GUIDE - BRIDE BUDDY V2

**Last Updated:** October 24, 2025
**Purpose:** Complete guide to deploying database schema and RLS policies

---

## 📋 OVERVIEW

You have **9 SQL migration files** in your project. Some are duplicates, some fix issues in others, and some are superseded. This guide tells you exactly which ones to run and in what order.

---

## 📁 ALL SQL FILES INVENTORY

### ✅ **FILES TO RUN** (Production Ready)

| File | Purpose | Tables Affected | Policies Created | Run Order |
|------|---------|----------------|------------------|-----------|
| `create_missing_tables.sql` | Creates 4 missing tables + triggers | profiles, chat_messages, pending_updates, invite_codes | None (just schema) | **1st** |
| `rls_critical_tables_fixed.sql` | RLS for core tables (no status column bug) | wedding_profiles, wedding_members | 9 policies total | **2nd** |
| `rls_remaining_tables.sql` | RLS for remaining tables | chat_messages, pending_updates, invite_codes, profiles | 15 policies total | **3rd** |
| `setup_bestie_functionality.sql` | Adds bestie role support | wedding_members, invite_codes, chat_messages | None (updates constraints) | **4th** |

### ⚠️ **FILES TO SKIP** (Superseded or Buggy)

| File | Issue | Replaced By |
|------|-------|-------------|
| `supabase_rls_migration.sql` | ❌ References non-existent `status` column | Use `rls_critical_tables_fixed.sql` + `rls_remaining_tables.sql` |
| `rls_critical_tables.sql` | ❌ References non-existent `status` column | Use `rls_critical_tables_fixed.sql` |
| `fix_wedding_members_rls.sql` | ⚠️ Addresses circular dependency (v1) | Use `fix_wedding_members_rls_v3.sql` if needed |
| `fix_wedding_members_rls_v2.sql` | ⚠️ Addresses circular dependency (v2) | Use `fix_wedding_members_rls_v3.sql` if needed |
| `fix_wedding_members_rls_v3.sql` | ⚠️ Most restrictive fix (only if issues occur) | Use only if circular dependency detected |

---

## 🚀 DEPLOYMENT ORDER (STEP-BY-STEP)

### **Step 1: Create Tables** ⏱️ 2 minutes

**Run:** `create_missing_tables.sql`

**What it does:**
- Creates `profiles` table (user profile data)
- Creates `chat_messages` table (AI conversation history)
- Creates `pending_updates` table (awaiting owner approval)
- Creates `invite_codes` table (invitation system)
- Creates trigger to auto-create profile on signup
- Creates `update_updated_at_column()` trigger function

**Tables Created:** 4
**Policies Created:** 0

**Verification Query:**
```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles',
    'chat_messages',
    'pending_updates',
    'invite_codes'
  )
ORDER BY tablename;
```
**Expected Result:** 4 tables listed

---

### **Step 2: Secure Critical Tables** ⏱️ 1 minute

**Run:** `rls_critical_tables_fixed.sql`

**What it does:**
- Enables RLS on `wedding_profiles`
- Enables RLS on `wedding_members`
- Creates 4 policies for wedding_profiles
- Creates 5 policies for wedding_members

**Important:** This is the FIXED version that doesn't reference the non-existent `status` column.

**Policies Created:**

**wedding_profiles (4 policies):**
1. `Users can view their weddings` - SELECT for authenticated users
2. `Users can create wedding as owner` - INSERT for authenticated users
3. `Owners can update their wedding` - UPDATE for owners only
4. `Backend full access` - ALL for service_role

**wedding_members (5 policies):**
1. `Users can view members of their wedding` - SELECT for authenticated users
2. `Users can join as owner` - INSERT as owner (wedding creation)
3. `Users can join as member` - INSERT as non-owner (via invite)
4. `Owners can manage members` - UPDATE for owners only
5. `Backend full access` - ALL for service_role

**Verification Query:**
```sql
-- Check RLS enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename IN ('wedding_profiles', 'wedding_members')
ORDER BY tablename;

-- Count policies
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN ('wedding_profiles', 'wedding_members')
GROUP BY tablename
ORDER BY tablename;
```
**Expected Result:**
- Both tables: `rowsecurity = true`
- wedding_profiles: 4 policies
- wedding_members: 5 policies

---

### **Step 3: Secure Remaining Tables** ⏱️ 1 minute

**Run:** `rls_remaining_tables.sql`

**What it does:**
- Enables RLS on `chat_messages`, `pending_updates`, `invite_codes`, `profiles`
- Creates 15 total policies across 4 tables

**Policies Created:**

**chat_messages (3 policies):**
1. `Users can view own chat messages` - SELECT own messages only
2. `Backend can insert messages` - INSERT for service_role
3. `Backend full access` - ALL for service_role

**pending_updates (4 policies):**
1. `Users can view wedding updates` - SELECT for wedding members
2. `Owners can approve/reject updates` - UPDATE for owners
3. `Backend can create updates` - INSERT for service_role
4. `Backend full access` - ALL for service_role

**invite_codes (3 policies):**
1. `Users can view wedding invites` - SELECT for wedding members
2. `Members can create invites` - INSERT for wedding members
3. `Backend full access` - ALL for service_role

**profiles (5 policies):**
1. `Users can view own profile` - SELECT own profile
2. `Users can view co-member profiles` - SELECT wedding co-members
3. `Users can create own profile` - INSERT on signup
4. `Users can update own profile` - UPDATE own profile
5. `Backend full access` - ALL for service_role

**Verification Query:**
```sql
-- Check RLS enabled on all 4 tables
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename IN (
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
)
ORDER BY tablename;

-- Count policies per table
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN (
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
)
GROUP BY tablename
ORDER BY tablename;
```
**Expected Result:**
- All 4 tables: `rowsecurity = true`
- chat_messages: 3 policies
- pending_updates: 4 policies
- invite_codes: 3 policies
- profiles: 5 policies

---

### **Step 4: Enable Bestie Functionality** ⏱️ 1 minute

**Run:** `setup_bestie_functionality.sql`

**What it does:**
- Adds `'bestie'` to `wedding_members.role` CHECK constraint
- Adds `role` column to `invite_codes` (if missing)
- Adds `'bestie'` to `invite_codes.role` CHECK constraint
- Updates `chat_messages.message_type` CHECK constraint to include 'bestie'

**This is required for:**
- MOH/Best Man invite system
- Bestie chat functionality
- Role-based access control

**Verification Query:**
```sql
-- Check constraints on wedding_members
SELECT
    con.conname AS constraint_name,
    pg_get_constraintdef(con.oid) AS constraint_definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'wedding_members'
  AND con.conname LIKE '%role%'
ORDER BY con.conname;

-- Check invite_codes has role column
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'invite_codes'
  AND column_name = 'role';
```
**Expected Result:**
- wedding_members.role CHECK includes: 'owner', 'member', 'bestie'
- invite_codes.role column exists with CHECK: 'member', 'bestie'

---

## 📊 FINAL VERIFICATION (Run All at Once)

After running all 4 files, run this comprehensive verification:

```sql
-- ============================================================================
-- COMPREHENSIVE DATABASE VERIFICATION
-- ============================================================================

-- 1. Check all 6 tables exist
SELECT
    tablename,
    CASE WHEN rowsecurity THEN '✓ RLS Enabled' ELSE '✗ RLS Disabled' END as security_status
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
-- Expected: All 6 tables with RLS Enabled

-- 2. Count total policies (should be 24)
SELECT COUNT(*) as total_policies
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

-- 3. Breakdown by table
SELECT
    tablename,
    COUNT(*) as policy_count,
    string_agg(DISTINCT cmd::text, ', ' ORDER BY cmd::text) as operations
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
-- chat_messages: 3 policies
-- invite_codes: 3 policies
-- pending_updates: 4 policies
-- profiles: 5 policies
-- wedding_members: 5 policies
-- wedding_profiles: 4 policies

-- 4. Check all triggers exist
SELECT
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table IN (
    'profiles',
    'pending_updates'
)
ORDER BY event_object_table, trigger_name;
-- Expected:
-- on_auth_user_created (triggers on auth.users)
-- update_profiles_updated_at (triggers on profiles)
-- update_pending_updates_updated_at (triggers on pending_updates)

-- 5. Verify bestie role support
SELECT
    table_name,
    constraint_name,
    check_clause
FROM information_schema.check_constraints
WHERE constraint_name LIKE '%role%'
  AND (constraint_name LIKE 'wedding_members%' OR constraint_name LIKE 'invite_codes%')
ORDER BY table_name;
-- Expected:
-- wedding_members: role IN ('owner', 'member', 'bestie')
-- invite_codes: role IN ('member', 'bestie')

-- 6. Verify message_type constraint
SELECT check_clause
FROM information_schema.check_constraints
WHERE constraint_name LIKE '%message_type%';
-- Expected: message_type IN ('main', 'bestie')
```

---

## 🎯 QUICK DEPLOYMENT CHECKLIST

Copy and paste this checklist:

```
BRIDE BUDDY V2 - SQL DEPLOYMENT CHECKLIST

□ Step 1: Run create_missing_tables.sql
  □ Verify 4 tables created
  □ Verify triggers created

□ Step 2: Run rls_critical_tables_fixed.sql
  □ Verify RLS enabled on wedding_profiles
  □ Verify RLS enabled on wedding_members
  □ Verify 9 total policies created

□ Step 3: Run rls_remaining_tables.sql
  □ Verify RLS enabled on chat_messages
  □ Verify RLS enabled on pending_updates
  □ Verify RLS enabled on invite_codes
  □ Verify RLS enabled on profiles
  □ Verify 15 policies created

□ Step 4: Run setup_bestie_functionality.sql
  □ Verify bestie role in wedding_members
  □ Verify bestie role in invite_codes
  □ Verify bestie in message_type constraint

□ Step 5: Run final verification query
  □ All 6 tables exist
  □ All 6 tables have RLS enabled
  □ Total of 24 policies exist
  □ All triggers exist
  □ Bestie constraints verified

□ Step 6: Test with application
  □ User signup creates profile
  □ User can create wedding
  □ User can view own wedding
  □ User cannot view other weddings
  □ Chat messages save correctly
```

---

## ⚠️ TROUBLESHOOTING

### Issue: "Column 'status' does not exist"

**Cause:** You ran `supabase_rls_migration.sql` or `rls_critical_tables.sql` (the buggy versions)

**Fix:**
1. Run `rls_critical_tables_fixed.sql` (which drops and recreates policies)
2. The fixed version doesn't reference the status column

### Issue: "Infinite recursion detected" or "Policy evaluation error"

**Cause:** Circular dependency in wedding_members SELECT policy

**Fix:**
1. Run `fix_wedding_members_rls_v3.sql`
2. This limits users to seeing only their own memberships
3. Backend APIs should use service role to query other members

### Issue: "Permission denied for table wedding_profiles"

**Cause:** RLS is enabled but policies aren't applied

**Fix:**
1. Verify you're authenticated: `SELECT auth.uid();` should return a UUID
2. Check you're a member: `SELECT * FROM wedding_members WHERE user_id = auth.uid();`
3. Re-run the RLS policy files

### Issue: "Check constraint violation on role"

**Cause:** Trying to insert 'bestie' role before running bestie setup

**Fix:**
1. Run `setup_bestie_functionality.sql`
2. This updates the CHECK constraints to allow 'bestie'

---

## 🔍 CHECKING WHAT'S ALREADY DEPLOYED

To see what's already in your Supabase database:

### Check Tables
```sql
SELECT
    tablename,
    CASE WHEN rowsecurity THEN '✓ RLS On' ELSE '✗ RLS Off' END as rls_status
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
```

### Check Policies
```sql
SELECT
    tablename,
    policyname,
    cmd as operation,
    roles
FROM pg_policies
WHERE tablename IN (
  'wedding_profiles',
  'wedding_members',
  'chat_messages',
  'pending_updates',
  'invite_codes',
  'profiles'
)
ORDER BY tablename, policyname;
```

### Check Constraints
```sql
-- Check for bestie role support
SELECT
    tc.table_name,
    tc.constraint_name,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name IN ('wedding_members', 'invite_codes', 'chat_messages')
  AND tc.constraint_type = 'CHECK'
ORDER BY tc.table_name, tc.constraint_name;
```

---

## 📝 POLICY REFERENCE

### Summary of All 24 Policies

| Table | Policy Count | Key Protection |
|-------|-------------|----------------|
| wedding_profiles | 4 | Users see only their weddings |
| wedding_members | 5 | Users see only their memberships |
| chat_messages | 3 | Users see only their own messages |
| pending_updates | 4 | Users see updates for their weddings |
| invite_codes | 3 | Users see invites for their weddings |
| profiles | 5 | Users see own + co-member profiles |

### Policy Types

- **SELECT policies:** Who can read data
- **INSERT policies:** Who can create new records
- **UPDATE policies:** Who can modify existing records
- **ALL policies:** Service role bypass (for backend APIs)

---

## 🎓 UNDERSTANDING RLS POLICIES

### The Security Model

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  User tries to access data                     │
│         ↓                                       │
│  RLS checks wedding_members table               │
│         ↓                                       │
│  Is user a member of this wedding?             │
│         ↓                                       │
│  YES: Allow access  |  NO: Deny access         │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Key Concepts

1. **authenticated role:** Regular users logged in via Supabase Auth
2. **service_role:** Backend APIs with elevated access (bypasses RLS)
3. **auth.uid():** Returns the current user's ID (null if not authenticated)
4. **USING clause:** Determines which rows user can access
5. **WITH CHECK clause:** Validates data being inserted/updated

---

## 🔐 SECURITY BEST PRACTICES

✅ **DO:**
- Always run migrations in a development/staging environment first
- Test authentication flows after applying RLS
- Use service role client in backend APIs for admin operations
- Verify policies with the provided queries

❌ **DON'T:**
- Disable RLS in production (emergency only)
- Use `USING (true)` for authenticated users (too permissive)
- Skip verification queries
- Run buggy files (with status column references)

---

## 📞 SUPPORT

If you encounter issues:

1. **Check the troubleshooting section above**
2. **Run verification queries to diagnose**
3. **Check Supabase logs:** Dashboard → Database → Logs
4. **Review the TECHNICAL_ARCHITECTURE_REVIEW.md file**

---

## ✅ SUCCESS CRITERIA

Your database is correctly configured when:

- ✅ All 6 tables exist
- ✅ All 6 tables have RLS enabled
- ✅ Total of 24 policies are active
- ✅ Triggers auto-create profiles on signup
- ✅ Bestie role constraints are in place
- ✅ Users can signup, create wedding, and chat
- ✅ Users cannot access other users' weddings
- ✅ Invite system works (after Edge Functions deployed)

---

**End of SQL Migration Guide**

# Bestie Permission System - Database Migrations

This directory contains SQL migrations for implementing the complete bestie permission system.

## Overview

These migrations implement the target architecture for the bestie system, enabling:
- **1:1 bestie-inviter relationship tracking**
- **Granular permission management** (can_read, can_edit)
- **Private bestie knowledge base** separate from chat
- **Secure RLS policies** enforcing permission boundaries

## Migration Files

Run these migrations **IN ORDER** in your Supabase SQL Editor:

### 001_add_invited_by_to_wedding_members.sql
**Purpose:** Track who invited each member to the wedding

**Changes:**
- Adds `invited_by_user_id` column to `wedding_members`
- Adds `wedding_profile_permissions` JSONB column
- Adds `created_at` timestamp
- Migrates existing data (sets invited_by based on invite_codes)
- Creates indexes for performance

**Run Time:** ~30 seconds
**Reversible:** Yes (rollback included)

---

### 002_create_bestie_permissions_table.sql
**Purpose:** Create table for bestie-inviter permission relationships

**Changes:**
- Creates `bestie_permissions` table
- Enforces 1:1 bestie-wedding constraint
- Prevents bestie from granting permissions to themselves
- Migrates existing bestie users (creates default permission records)
- Creates indexes and triggers

**Run Time:** ~30 seconds
**Reversible:** Yes (rollback included)

**Key Constraint:**
```sql
UNIQUE (bestie_user_id, wedding_id)
-- Each bestie can only belong to ONE inviter per wedding
```

---

### 003_create_bestie_knowledge_table.sql
**Purpose:** Create dedicated storage for bestie's planning knowledge

**Changes:**
- Creates `bestie_knowledge` table
- Supports knowledge types: note, vendor, task, expense, idea, checklist, contact
- Privacy flag (`is_private`) for ultra-private surprises
- Full-text search capability
- Helper functions for search and summaries

**Run Time:** ~30 seconds
**Reversible:** Yes (rollback included)

**Features:**
- Structured storage (vs chat messages)
- Categorization by type
- Full-text search on content
- Flexible metadata JSONB field

---

### 004_rls_bestie_permissions.sql
**Purpose:** Secure bestie_permissions table with Row Level Security

**Policies Created:**
1. ✅ Bestie can SELECT only their own permission record
2. ✅ Bestie can UPDATE only their own record (cannot change IDs)
3. ✅ Inviter can SELECT to check what access they have
4. ✅ Backend (service_role) has full access

**Run Time:** ~10 seconds
**Reversible:** Yes (rollback included)

**Security:**
- Bestie CANNOT see other besties' permissions
- Bestie CANNOT update other besties' permissions
- Bestie CANNOT change who they granted permissions to

**Helper Views:**
- `my_bestie_permissions` - For besties to check their status
- `my_besties` - For inviters to see their besties

---

### 005_rls_bestie_knowledge.sql
**Purpose:** Secure bestie_knowledge table with Row Level Security

**Policies Created:**
1. ✅ Bestie has full CRUD on their own knowledge
2. ✅ Inviter can SELECT if granted `can_read=true` AND not private
3. ✅ Inviter can UPDATE if granted `can_edit=true` AND not private
4. ✅ Backend (service_role) has full access

**Run Time:** ~10 seconds
**Reversible:** Yes (rollback included)

**Security:**
- Private knowledge (`is_private=true`) is ALWAYS invisible to inviter
- Inviter cannot steal ownership of knowledge
- Permissions checked via JOIN to bestie_permissions table

**Helper Views:**
- `my_bestie_knowledge_summary` - Stats for besties
- `accessible_bestie_knowledge` - What inviter can see

---

## How to Run

### Step 1: Backup Your Database
```bash
# In Supabase Dashboard: Database → Backups → Create Backup
```

### Step 2: Open SQL Editor
```
Supabase Dashboard → SQL Editor → New Query
```

### Step 3: Run Migrations in Order

**Migration 001:**
```sql
-- Copy/paste contents of 001_add_invited_by_to_wedding_members.sql
-- Click "Run" button
-- Verify: Check verification section output shows members_with_inviter > 0
```

**Migration 002:**
```sql
-- Copy/paste contents of 002_create_bestie_permissions_table.sql
-- Click "Run" button
-- Verify: Check verification section shows total_bestie_permissions count
```

**Migration 003:**
```sql
-- Copy/paste contents of 003_create_bestie_knowledge_table.sql
-- Click "Run" button
-- Verify: Check table structure appears correctly
```

**Migration 004:**
```sql
-- Copy/paste contents of 004_rls_bestie_permissions.sql
-- Click "Run" button
-- Verify: Check policy_count = 4
```

**Migration 005:**
```sql
-- Copy/paste contents of 005_rls_bestie_knowledge.sql
-- Click "Run" button
-- Verify: Check policy_count = 7
```

### Step 4: Verify Complete Deployment

Run this verification query:
```sql
-- Check all tables exist
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'wedding_members',
    'bestie_permissions',
    'bestie_knowledge'
  )
ORDER BY tablename;
-- Should return 3 rows

-- Check all RLS policies exist
SELECT
  tablename,
  COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN ('bestie_permissions', 'bestie_knowledge')
GROUP BY tablename
ORDER BY tablename;
-- Should show:
-- bestie_permissions: 4 policies
-- bestie_knowledge: 7 policies

-- Check columns added to wedding_members
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'wedding_members'
  AND column_name IN ('invited_by_user_id', 'wedding_profile_permissions', 'created_at')
ORDER BY column_name;
-- Should return 3 rows
```

---

## Rollback Instructions

If you need to rollback any migration, each file contains a commented-out rollback section at the bottom.

**To rollback Migration 005:**
```sql
-- Uncomment and run the ROLLBACK section from 005_rls_bestie_knowledge.sql
```

**To rollback all migrations (reverse order):**
```sql
-- Run rollback section from 005
-- Run rollback section from 004
-- Run rollback section from 003
-- Run rollback section from 002
-- Run rollback section from 001
```

---

## Post-Migration Checklist

After running all migrations, verify:

- [ ] `wedding_members` has `invited_by_user_id` column
- [ ] All existing members have `invited_by_user_id` populated (not NULL)
- [ ] `bestie_permissions` table exists
- [ ] All existing besties have permission records
- [ ] `bestie_knowledge` table exists
- [ ] RLS is enabled on `bestie_permissions` (4 policies)
- [ ] RLS is enabled on `bestie_knowledge` (7 policies)
- [ ] Helper views are accessible: `my_bestie_permissions`, `my_besties`, `my_bestie_knowledge_summary`, `accessible_bestie_knowledge`

---

## What Changed

### Before (Current System)
```
wedding_members:
- wedding_id
- user_id
- role (owner/member/bestie)

chat_messages:
- message_type ('main' or 'bestie')  ← Only bestie data storage

NO permission system
NO inviter tracking
NO knowledge base
```

### After (Target Architecture)
```
wedding_members:
- wedding_id
- user_id
- role
- invited_by_user_id          ← NEW
- wedding_profile_permissions ← NEW
- created_at                  ← NEW

bestie_permissions:           ← NEW TABLE
- bestie_user_id
- inviter_user_id
- wedding_id
- permissions (can_read, can_edit)
- UNIQUE constraint enforcing 1:1 relationship

bestie_knowledge:             ← NEW TABLE
- bestie_user_id
- wedding_id
- content
- knowledge_type
- is_private
- Full-text search enabled

RLS Policies:                 ← NEW SECURITY
- Besties can only manage their own data
- Inviters need permission to access bestie knowledge
- Private knowledge always hidden from inviter
```

---

## Next Steps

After completing Phase 1 (Database Schema), proceed to:

**Phase 2: API Endpoints** (4-5 hours)
- Create `/api/create-bestie-invite.js`
- Create `/api/accept-bestie-invite.js`
- Create `/api/get-my-bestie-permissions.js`
- Create `/api/update-my-inviter-access.js`

See `BESTIE_SYSTEM_AUDIT.md` for complete implementation roadmap.

---

## Troubleshooting

**Issue:** Migration 001 fails with "column already exists"
```
Solution: Column was added manually - safe to continue
```

**Issue:** Migration 002 fails with "some besties have NULL invited_by_user_id"
```
Solution: Run Migration 001 first to populate invited_by_user_id
```

**Issue:** RLS policies prevent queries
```
Solution: Verify you're using service_role key for backend operations
         Or ensure auth.uid() returns correct user ID for authenticated queries
```

**Issue:** Full-text search not working on bestie_knowledge
```
Solution: Check GIN index was created: bestie_knowledge_content_search_idx
```

---

## Support

For questions or issues:
1. Check verification queries in each migration file
2. Review `BESTIE_SYSTEM_AUDIT.md` for architecture details
3. Examine rollback sections for safe reversal
4. Test RLS policies with test scenarios in migration files

---

**Phase 1 Implementation:** Database Schema ✅ COMPLETE
**Estimated Total Run Time:** ~2 minutes
**All Migrations Reversible:** Yes

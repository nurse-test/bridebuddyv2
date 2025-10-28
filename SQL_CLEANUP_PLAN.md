# SQL Files Cleanup Plan

**Date:** 2025-10-28
**Total SQL Files Found:** 27
**Files to Keep:** 14
**Files to Archive:** 7
**Files to Delete:** 6

---

## Issues Found

### 🚨 Critical Issues

1. **DUPLICATE Migration 008**
   - `008_add_engagement_and_onboarding_data.sql` (1.8K)
   - `008_fix_wedding_members_rls_recursion.sql` (2.1K)
   - **Impact:** Breaks migration ordering
   - **Solution:** Renumber one to 013

2. **FOUR Migration 015 Versions**
   - `015_create_bestie_profile_table.sql` (original)
   - `015_create_bestie_profile_table_FIXED.sql` (failed attempt)
   - `015_create_bestie_profile_SIMPLE.sql` (failed attempt)
   - `015_create_bestie_profile_CLEANEST.sql` (working version)
   - **Impact:** Confusion about which to use
   - **Solution:** Keep CLEANEST, archive others

3. **Missing Migration 013**
   - Numbers jump from 012 → 014
   - **Solution:** Renumber duplicate 008 to fill gap

---

## Current File Structure

### Migrations Directory (18 files)

```
✅ 001_add_invited_by_to_wedding_members.sql          (5.7K)  - KEEP
✅ 002_create_bestie_permissions_table.sql            (8.1K)  - KEEP
⚠️  003_create_bestie_knowledge_table.sql             (9.7K)  - KEEP but table unused
⚠️  004_rls_bestie_permissions.sql                    (9.1K)  - KEEP but for unused table
⚠️  005_rls_bestie_knowledge.sql                      (14K)   - KEEP but for unused table
✅ 006_unified_invite_system.sql                      (9.9K)  - KEEP
✅ 007_add_missing_wedding_profile_columns.sql        (12K)   - KEEP
🔴 008_add_engagement_and_onboarding_data.sql         (1.8K)  - RENUMBER TO 013
🔴 008_fix_wedding_members_rls_recursion.sql          (2.1K)  - KEEP AS 008
✅ 009_create_vendor_tracker_table.sql                (3.3K)  - KEEP
✅ 010_create_budget_tracker_table.sql                (3.3K)  - KEEP
✅ 011_create_wedding_tasks_table.sql                 (3.4K)  - KEEP
✅ 012_add_color_scheme_secondary.sql                 (239)   - KEEP
✅ 014_correct_wedding_architecture.sql               (16K)   - KEEP
🔴 015_create_bestie_profile_table.sql                (4.2K)  - ARCHIVE
🔴 015_create_bestie_profile_table_FIXED.sql          (5.3K)  - ARCHIVE
🔴 015_create_bestie_profile_SIMPLE.sql               (3.7K)  - ARCHIVE
✅ 015_create_bestie_profile_CLEANEST.sql             (3.8K)  - RENAME TO 015.sql
✅ 016_fix_chat_visibility_for_couples.sql            (1.4K)  - KEEP
✅ 017_add_subscription_dates.sql                     (956)   - KEEP
✅ 018_cleanup_unused_tables.sql                      (2.5K)  - KEEP
```

### Root Directory (7 files)

```
✅ database_init.sql                  - KEEP (master init script)
✅ database_status_check.sql          - KEEP (verification script)
✅ check_bestie_profile_status.sql    - KEEP (recent diagnostic)
🔴 create_missing_tables.sql          - ARCHIVE (old, merged into migrations)
🔴 fix_wedding_members_rls_v3.sql     - ARCHIVE (old, replaced by migration 008)
🔴 rls_critical_tables_fixed.sql      - ARCHIVE (old, replaced by migrations)
🔴 rls_remaining_tables.sql           - ARCHIVE (old, replaced by migrations)
```

---

## Cleanup Actions

### Action 1: Create Archive Directory

```bash
mkdir -p migrations/archive
```

### Action 2: Renumber Duplicate Migration 008

**Rename:**
```bash
# Move engagement data migration to 013
mv migrations/008_add_engagement_and_onboarding_data.sql \
   migrations/013_add_engagement_and_onboarding_data.sql
```

**Keep as 008:**
- `008_fix_wedding_members_rls_recursion.sql` (more critical, RLS fix)

### Action 3: Consolidate Migration 015

**Keep (rename for clarity):**
```bash
mv migrations/015_create_bestie_profile_CLEANEST.sql \
   migrations/015_create_bestie_profile_table.sql
```

**Archive the failed attempts:**
```bash
mv migrations/015_create_bestie_profile_table.sql \
   migrations/archive/015_create_bestie_profile_table_ORIGINAL.sql

mv migrations/015_create_bestie_profile_table_FIXED.sql \
   migrations/archive/015_create_bestie_profile_table_FIXED.sql

mv migrations/015_create_bestie_profile_SIMPLE.sql \
   migrations/archive/015_create_bestie_profile_SIMPLE.sql
```

### Action 4: Archive Old Root Directory Files

```bash
mkdir -p archive/old_sql_scripts

mv create_missing_tables.sql archive/old_sql_scripts/
mv fix_wedding_members_rls_v3.sql archive/old_sql_scripts/
mv rls_critical_tables_fixed.sql archive/old_sql_scripts/
mv rls_remaining_tables.sql archive/old_sql_scripts/
```

### Action 5: Update migrations/README.md

Add documentation for migrations 006-018 to match the existing format for 001-005.

---

## Final Structure After Cleanup

### Migrations Directory (14 files - clean sequence)

```
migrations/
├── 001_add_invited_by_to_wedding_members.sql
├── 002_create_bestie_permissions_table.sql
├── 003_create_bestie_knowledge_table.sql
├── 004_rls_bestie_permissions.sql
├── 005_rls_bestie_knowledge.sql
├── 006_unified_invite_system.sql
├── 007_add_missing_wedding_profile_columns.sql
├── 008_fix_wedding_members_rls_recursion.sql
├── 009_create_vendor_tracker_table.sql
├── 010_create_budget_tracker_table.sql
├── 011_create_wedding_tasks_table.sql
├── 012_add_color_scheme_secondary.sql
├── 013_add_engagement_and_onboarding_data.sql    ← RENUMBERED
├── 014_correct_wedding_architecture.sql
├── 015_create_bestie_profile_table.sql           ← CONSOLIDATED
├── 016_fix_chat_visibility_for_couples.sql
├── 017_add_subscription_dates.sql
├── 018_cleanup_unused_tables.sql
├── README.md                                     ← UPDATED
└── archive/
    ├── 015_create_bestie_profile_table_ORIGINAL.sql
    ├── 015_create_bestie_profile_table_FIXED.sql
    └── 015_create_bestie_profile_SIMPLE.sql
```

### Root Directory (3 files - only active utilities)

```
/
├── database_init.sql
├── database_status_check.sql
├── check_bestie_profile_status.sql
└── archive/
    └── old_sql_scripts/
        ├── create_missing_tables.sql
        ├── fix_wedding_members_rls_v3.sql
        ├── rls_critical_tables_fixed.sql
        └── rls_remaining_tables.sql
```

---

## Benefits

1. **Clean Migration Sequence:** No duplicate numbers (001-018 sequential)
2. **Single Source of Truth:** One version of each migration
3. **Clear History:** Archive preserves old attempts for reference
4. **Updated Documentation:** README covers all migrations
5. **Easier Onboarding:** New developers see clean structure

---

## Verification Steps

After cleanup:

1. **Check migration sequence:**
   ```bash
   ls -1 migrations/*.sql | grep -E '^migrations/[0-9]{3}_' | sort
   ```
   Should show 001-018 with no gaps or duplicates

2. **Verify no broken references:**
   ```bash
   grep -r "008_add_engagement" . --include="*.md" --include="*.sql"
   grep -r "015_create_bestie_profile_table.sql" . --include="*.md"
   ```

3. **Test migrations can be run in order:**
   - Each migration should be idempotent
   - Should handle "already exists" cases gracefully

---

## Notes on Unused Tables

Migrations 003, 004, 005 create and secure the `bestie_knowledge` table which:
- ✅ Has proper migrations
- ✅ Has RLS policies
- ❌ Is NOT used anywhere in application code
- ❌ Was identified for deletion in migration 018

**Recommendation:** Keep migrations for now (history), but table was correctly identified as unused in the audit.

---

## Implementation Order

1. ✅ Create archive directories
2. ✅ Move old root SQL files to archive
3. ✅ Move migration 015 variants to archive
4. ✅ Rename migration 008 (engagement) to 013
5. ✅ Rename migration 015 CLEANEST to standard name
6. ✅ Update migrations/README.md
7. ✅ Commit all changes
8. ✅ Push to GitHub

---

**Status:** Ready to implement
**Risk Level:** Low (all files archived, not deleted)
**Reversible:** Yes (archived files can be restored)

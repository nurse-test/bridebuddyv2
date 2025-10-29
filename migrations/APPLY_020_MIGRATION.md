# Applying Migration 020: Fix Invite Functions Schema

## Problem

The invite creation endpoint was failing with:
```json
{
  "error": "Failed to create invite link",
  "details": "Could not find the 'used' column of 'invite_codes' in the schema cache"
}
```

## Root Cause

Migration 006 created database functions that reference a `used` column, but the actual table has an `is_used` column:

**Functions with schema mismatch:**
1. `is_invite_valid(token TEXT)` - checks if invite is valid
2. `get_invite_details(token TEXT)` - returns invite details
3. `active_invites` view - shows active invites

These functions were using:
- `ic.used` → should be `ic.is_used`
- `ic.expires_at` → should be removed (one-time use only)

## Solution

Run migration 020 to fix all database functions and views.

## How to Apply

### Option 1: Run the migration file directly

```bash
# In Supabase SQL Editor:
# 1. Open migrations/020_fix_invite_functions_schema.sql
# 2. Copy and paste the entire contents
# 3. Execute
```

### Option 2: Rebuild from database_init.sql

If you're starting fresh or want to ensure everything is correct:

```bash
# In Supabase SQL Editor:
# 1. Open database_init.sql
# 2. Copy and paste the entire contents
# 3. Execute
# This includes migration 020 as STEP 9.5
```

## What Gets Fixed

✅ `is_invite_valid(token)` - Now uses `is_used` column
✅ `get_invite_details(token)` - Now uses `is_used` column
✅ `active_invites` view - Now uses `is_used` column
✅ Removed all `expires_at` references (one-time use only)
✅ Created `cleanup_old_used_invites()` function

## Verification

After applying the migration, test:

1. **Create an invite:**
   ```javascript
   // Should succeed without schema cache errors
   POST /api/create-invite
   {
     "userToken": "...",
     "role": "partner"
   }
   ```

2. **Check database functions:**
   ```sql
   -- Should return function definition with is_used (not used)
   \df is_invite_valid
   \df get_invite_details

   -- Should work without errors
   SELECT * FROM active_invites;
   ```

## Files Changed

- `migrations/020_fix_invite_functions_schema.sql` - New migration
- `database_init.sql` - Added STEP 9.5 with function fixes

## Related Issues

This fixes the errors reported in:
- 400 errors on wedding_members queries
- 400/500 errors on invite_codes queries
- 500 error from /api/create-invite endpoint

All caused by database functions using wrong column name.

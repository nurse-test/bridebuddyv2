# Migration 008: Fix RLS Policy Recursion

## Problem

The application was experiencing an **infinite recursion error** in Row Level Security (RLS) policies:

```
Error: infinite recursion detected in policy for relation "wedding_members"
```

### Root Cause

The "Users can view members of their wedding" policy on `wedding_members` was querying the same `wedding_members` table from within the policy:

```sql
CREATE POLICY "Users can view members of their wedding"
ON wedding_members FOR SELECT
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members  -- ❌ Recursion!
    WHERE user_id = auth.uid()
  )
);
```

This created an infinite loop:
1. User tries to SELECT from `wedding_members`
2. Policy checks: "is wedding_id in (SELECT from wedding_members...)"
3. To execute that SELECT, it needs to check the same policy again
4. **INFINITE RECURSION** 🔄

The same issue existed in the "Owners can manage members" UPDATE policy.

## Solution

Created **SECURITY DEFINER functions** that bypass RLS policies, breaking the recursion chain:

1. `is_wedding_member(wedding_id, user_id)` - Checks if user is a member
2. `is_wedding_owner(wedding_id, user_id)` - Checks if user is the owner

These functions can safely query `wedding_members` because SECURITY DEFINER runs with elevated privileges and bypasses RLS.

## How to Apply

### Option 1: Run Migration File (Existing Databases)

In Supabase SQL Editor, run:

```sql
-- Copy and paste the contents of:
migrations/008_fix_wedding_members_rls_recursion.sql
```

### Option 2: Fresh Database Setup

For new deployments, just run `database_init.sql` - it already includes these fixes.

## What Changed

### Before (Recursive):
```sql
-- ❌ This causes infinite recursion
CREATE POLICY "Users can view members of their wedding"
ON wedding_members FOR SELECT
USING (
  wedding_id IN (
    SELECT wedding_id FROM wedding_members WHERE user_id = auth.uid()
  )
);
```

### After (Non-Recursive):
```sql
-- ✅ Function bypasses RLS, breaking recursion
CREATE FUNCTION is_wedding_member(p_wedding_id UUID, p_user_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_id = p_wedding_id AND user_id = p_user_id
  );
$$;

-- ✅ Policy uses function instead of direct query
CREATE POLICY "Users can view wedding members"
ON wedding_members FOR SELECT
USING (
  is_wedding_member(wedding_id, auth.uid())
);
```

## Verification

After applying the migration, verify it works:

```sql
-- Should return rows without error
SELECT * FROM wedding_members WHERE user_id = auth.uid();

-- Check that policies are using the functions
SELECT policyname, pg_get_expr(qual, polrelid) as using_expression
FROM pg_policy
WHERE polrelid = 'wedding_members'::regclass;
```

Expected output should show policies using `is_wedding_member()` and `is_wedding_owner()` functions.

## Files Modified

- `migrations/008_fix_wedding_members_rls_recursion.sql` - New migration file
- `database_init.sql` - Updated with helper functions and fixed policies

## Impact

- **✅ Fixes:** Dashboard loading error and all wedding member queries
- **✅ Security:** Maintains same access control logic
- **✅ Performance:** Functions are marked STABLE for query optimization
- **⚠️ Important:** Run this migration ASAP - the app is broken without it

## Technical Notes

**SECURITY DEFINER Functions:**
- Execute with privileges of the function owner (usually superuser)
- Bypass RLS policies when querying tables
- Marked STABLE (not VOLATILE) for better performance
- Safe because they only check membership, don't modify data

**Why This Works:**
- When RLS policy calls `is_wedding_member()`, the function runs with elevated privileges
- Function query bypasses RLS entirely, so no policy check needed
- This breaks the recursion chain ✂️

## Related Issues

- Fixes error when loading dashboard: `wedding_members` recursion
- Fixes error when viewing team members
- Fixes error when checking permissions
- Enables all member-related queries to work properly

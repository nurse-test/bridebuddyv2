# Row Level Security (RLS) Policy Guide

## Quick Reference

### Tables & Security Model

| Table | RLS Enabled | Access Model | Can Insert | Can Update | Can Delete |
|-------|-------------|--------------|------------|------------|------------|
| **wedding_profiles** | ✅ Yes | Wedding members only | Owner creates | Owner only | ❌ No |
| **wedding_members** | ✅ Yes | Wedding members only | Self-join allowed | Owner manages | ❌ No |
| **chat_messages** | ✅ Yes | Own messages only | Backend only | ❌ No | ❌ No |
| **pending_updates** | ✅ Yes | Wedding members view | Backend only | Owner approves | ❌ No |
| **invite_codes** | ✅ Yes | Wedding members only | Members create | Backend marks used | ❌ No |
| **profiles** | ✅ Yes | Own + co-members | Self on signup | Own only | ❌ No |

---

## Security Principles

### 1. **Wedding Membership Model**
All data access is based on the `wedding_members` table. Users can only:
- View data for weddings they're a member of
- Access profiles of other members in same wedding
- See chat messages they created

### 2. **Role-Based Access**
- **Owner:** Full control of wedding data, can approve updates, manage members
- **Member:** Can view wedding data, create invites, chat
- **Service Role (Backend):** Full access for AI operations and payments

### 3. **Data Isolation**
- Each wedding is isolated from others
- Users in Wedding A cannot see data from Wedding B
- Chat messages are further isolated by user_id

---

## How to Apply

### Step 1: Run the Migration
```sql
-- In Supabase Dashboard → SQL Editor → New Query
-- Copy and paste the entire content of supabase_rls_migration.sql
-- Click "Run"
```

### Step 2: Verify RLS is Enabled
```sql
-- Check all tables have RLS enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename IN (
  'wedding_profiles', 'wedding_members', 'chat_messages',
  'pending_updates', 'invite_codes', 'profiles'
)
ORDER BY tablename;
```

Expected output: `rowsecurity = true` for all tables

### Step 3: Verify Policies
```sql
-- Count policies per table
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN (
  'wedding_profiles', 'wedding_members', 'chat_messages',
  'pending_updates', 'invite_codes', 'profiles'
)
GROUP BY tablename
ORDER BY tablename;
```

Expected policy counts:
- wedding_profiles: 4 policies
- wedding_members: 5 policies
- chat_messages: 3 policies
- pending_updates: 4 policies
- invite_codes: 3 policies
- profiles: 5 policies

---

## Testing the Policies

### Test 1: User Can View Own Wedding
```sql
-- As authenticated user
SELECT * FROM wedding_profiles;
-- Should return only weddings where user is a member
```

### Test 2: User Cannot View Other Weddings
```sql
-- Try to access a wedding_id you're not a member of
SELECT * FROM wedding_profiles WHERE id = 'some-other-wedding-id';
-- Should return 0 rows
```

### Test 3: Owner Can Update Wedding
```sql
-- As wedding owner
UPDATE wedding_profiles
SET wedding_name = 'New Name'
WHERE id = 'your-wedding-id';
-- Should succeed
```

### Test 4: Non-Owner Cannot Update
```sql
-- As wedding member (not owner)
UPDATE wedding_profiles
SET wedding_name = 'Hacked'
WHERE id = 'your-wedding-id';
-- Should fail with permission denied
```

---

## Common Issues & Solutions

### Issue 1: "Row-level security policy violated"
**Cause:** User trying to access data they don't have permission for

**Solutions:**
- Check user is authenticated (`auth.uid()` returns a value)
- Verify user is a member of the wedding (`wedding_members` entry exists)
- Confirm `status = 'active'` in `wedding_members`

### Issue 2: Service role queries failing
**Cause:** Service role policies not applied

**Solution:**
- Ensure environment variable uses `SUPABASE_SERVICE_ROLE_KEY`
- Check API files use service role client for backend operations

### Issue 3: Chat messages not appearing
**Cause:** Messages must match both `wedding_id` AND `user_id`

**Solution:**
- Verify chat messages are inserted with correct `user_id`
- Check `wedding_id` matches user's wedding membership

---

## Policy Updates

If you need to modify policies later:

### Disable RLS Temporarily (DANGEROUS - Dev Only)
```sql
ALTER TABLE wedding_profiles DISABLE ROW LEVEL SECURITY;
-- Remember to re-enable after testing!
```

### Add New Policy
```sql
CREATE POLICY "policy_name"
ON table_name FOR SELECT  -- or INSERT, UPDATE, DELETE, ALL
TO authenticated           -- or service_role, anon, public
USING (condition);         -- for SELECT and UPDATE
WITH CHECK (condition);    -- for INSERT and UPDATE
```

### Drop Policy
```sql
DROP POLICY IF EXISTS "policy_name" ON table_name;
```

---

## Security Best Practices

✅ **DO:**
- Keep RLS enabled on all tables in production
- Use service role only in backend API endpoints
- Test policies thoroughly before deploying
- Use specific policies (SELECT, INSERT, etc.) instead of ALL when possible

❌ **DON'T:**
- Disable RLS in production
- Use service role key in frontend code
- Create overly permissive policies (e.g., `USING (true)` for users)
- Skip the verification queries after migration

---

## Support

For Supabase RLS documentation:
https://supabase.com/docs/guides/auth/row-level-security

For policy examples:
https://supabase.com/docs/guides/auth/row-level-security#policies

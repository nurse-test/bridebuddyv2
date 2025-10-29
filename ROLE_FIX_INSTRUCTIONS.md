# Partner Role Fix Instructions

## Problem
The `wedding_members` table CHECK constraint only allowed: `'owner'`, `'member'`, `'bestie'`

This caused partner invites to fail or show as "co-planner" with wrong permissions.

## Solution
Run the SQL script to add `'partner'` as a valid role.

## Steps

### 1. Run SQL Fix (REQUIRED)
Open Supabase SQL Editor and run:
```sql
-- Drop the old CHECK constraint
ALTER TABLE wedding_members
DROP CONSTRAINT IF EXISTS wedding_members_role_check;

-- Add new CHECK constraint with 'partner' role
ALTER TABLE wedding_members
ADD CONSTRAINT wedding_members_role_check
CHECK (role IN ('owner', 'partner', 'bestie'));
```

Or simply run the file: `fix_partner_role.sql`

### 2. Deploy Code Changes
The API has been updated to use 'partner' role directly.
Deploy the latest code from this branch.

## Result

After running the SQL:

### Valid Roles:
- **owner**: Wedding creator (full access)
- **partner**: Fiancé(e) (full access - same as owner)
- **bestie**: MOH/Best Man (bestie chat only, no wedding profile access)

### Permissions:
- Owner: `{read: true, edit: true}`
- Partner: `{read: true, edit: true}` ✅ FULL ACCESS
- Bestie: `{read: false, edit: false}` (bestie chat only)

### What Partner Can Do:
✅ Edit all wedding details
✅ Manage vendors
✅ Update budget
✅ Assign tasks
✅ Chat with AI
✅ Full co-planning access

## Verification

After applying the fix, test:

1. Create partner invite
2. Accept invite in different browser
3. Verify role shows as "Partner" (not "co-planner")
4. Verify partner can EDIT wedding details
5. Check wedding_members table shows role='partner'

## Migration Note

The old constraint only allowed 'member' role, which we were using for partner.
Now we use the proper 'partner' role for clarity and correct permissions display.

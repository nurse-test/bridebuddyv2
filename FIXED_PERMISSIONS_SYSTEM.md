# Fixed Role-Based Permissions System

**Last Updated:** 2025-10-29
**Migration:** 022_fixed_role_based_permissions.sql

---

## Overview

The invite system now uses **FIXED role-based permissions** instead of manual permission toggles. Permissions are determined entirely by the user's role in `wedding_members` and enforced at the database level via RLS policies.

**Key Principle:** Your role determines what you can access. No toggles, no settings, no confusion.

---

## Permission Matrix

### Owner & Partner - Full Wedding Access

| Resource | Access Level | Notes |
|----------|-------------|-------|
| `wedding_profiles` | ✅ **VIEW + EDIT** | Full control over wedding details |
| `wedding_members` | ✅ **VIEW + EDIT** | Can manage team members |
| `chat_messages` (main) | ✅ **VIEW + CREATE** | Main wedding planning chat |
| `invite_codes` | ✅ **VIEW + CREATE** | Can create partner/bestie invites |
| `pending_updates` | ✅ **VIEW + EDIT** | Can approve/reject AI updates |
| `vendor_tracker` | ✅ **VIEW + EDIT** | Full vendor management |
| `budget_tracker` | ✅ **VIEW + EDIT** | Full budget management |
| `wedding_tasks` | ✅ **VIEW + EDIT** | Full task management |
| | | |
| `bestie_knowledge` | ❌ **ZERO ACCESS** | Cannot see, edit, or know it exists |
| `bestie_profile` | ❌ **ZERO ACCESS** | Cannot see bestie planning |
| `bestie_permissions` | ❌ **DEPRECATED** | Table no longer used |
| `chat_messages` (bestie) | ❌ **ZERO ACCESS** | Cannot see bestie chats |

**Privacy Guarantee:** Owners and Partners **cannot** access any bestie planning data. The database will reject all queries.

---

### Bestie - View Wedding + Private Planning

| Resource | Access Level | Notes |
|----------|-------------|-------|
| `wedding_profiles` | ✅ **VIEW ONLY** | Can read wedding details for context |
| `wedding_members` | ✅ **VIEW ONLY** | Can see who's on the team |
| `bestie_knowledge` | ✅ **VIEW + EDIT** | Full access to OWN knowledge only |
| `bestie_profile` | ✅ **VIEW + EDIT** | Full access to OWN profile only |
| `chat_messages` (bestie) | ✅ **VIEW + CREATE** | Private bestie planning chat |
| | | |
| `wedding_profiles` | ❌ **NO EDIT** | Cannot modify wedding details |
| `invite_codes` | ❌ **ZERO ACCESS** | Cannot create invites |
| `pending_updates` | ❌ **ZERO ACCESS** | Cannot approve/reject updates |
| `vendor_tracker` | ❌ **ZERO ACCESS** | Cannot see vendor details |
| `budget_tracker` | ❌ **ZERO ACCESS** | Cannot see budget |
| `wedding_tasks` | ❌ **ZERO ACCESS** | Cannot see tasks |
| `chat_messages` (main) | ❌ **ZERO ACCESS** | Cannot see main wedding chat |
| OTHER besties' data | ❌ **ZERO ACCESS** | Each bestie only sees their own |

**Privacy Guarantee:** Besties can **view** wedding details (date, venue, theme) to inform their planning, but **cannot edit** anything. Their planning space is **completely private** from the couple.

---

## How It Works

### 1. Role Assignment

Roles are assigned when users join a wedding:
- **Owner:** Automatically assigned when creating a wedding
- **Partner:** Assigned when accepting a partner invite
- **Bestie:** Assigned when accepting a bestie invite

Role is stored in `wedding_members.role` column.

### 2. Database Enforcement (RLS Policies)

Every table has Row Level Security (RLS) policies that check the user's role:

```sql
-- Example: wedding_profiles SELECT policy
CREATE POLICY "Wedding members can view wedding profile"
ON wedding_profiles FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

-- Example: wedding_profiles UPDATE policy (Owner/Partner only)
CREATE POLICY "Owners and partners can update wedding"
ON wedding_profiles FOR UPDATE
TO authenticated
USING (
  id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role IN ('owner', 'partner')  -- ← Role check
  )
);
```

### 3. Chat Message Separation

Chat messages are separated by `message_type`:
- `'main'` - Wedding planning chat (Owner/Partner only)
- `'bestie'` - Private bestie planning (Bestie only)

```sql
-- Owners/Partners can only see main chat
CREATE POLICY "Users can view own chat messages by type"
ON chat_messages FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  AND (
    (message_type = 'main' AND role IN ('owner', 'partner'))
    OR
    (message_type = 'bestie' AND role = 'bestie')
  )
);
```

### 4. Bestie Knowledge Isolation

Each bestie's knowledge is completely isolated:

```sql
-- Only the bestie owner can access their own knowledge
CREATE POLICY "Besties can view own knowledge"
ON bestie_knowledge FOR SELECT
TO authenticated
USING (
  bestie_user_id = auth.uid()  -- ← Must be the bestie owner
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_knowledge.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'  -- ← Must have bestie role
  )
);
```

---

## What Happened to Manual Permissions?

### Before (Manual Permissions)

❌ Bestie accepts invite → Toggles checkboxes:
- [ ] Allow inviter to view my bestie knowledge
- [ ] Allow inviter to edit my bestie knowledge

❌ Data stored in `bestie_permissions` table
❌ Confusing for users ("What should I check?")
❌ Complex RLS policies checking permissions

### After (Fixed Permissions)

✅ Bestie accepts invite → Sees privacy notice:
> **Privacy Guarantee:** The couple cannot see, edit, or even know your bestie planning exists. Your space is completely private.

✅ `bestie_permissions` table deprecated (kept for historical data)
✅ Clear expectation: Role = Permissions
✅ Simple RLS policies checking role only

---

## Migration Guide

### For Existing Databases

Run migration `022_fixed_role_based_permissions.sql`:

```bash
# In Supabase SQL Editor, run:
migrations/022_fixed_role_based_permissions.sql
```

This migration will:
1. ✅ Deprecate `bestie_permissions` table (adds comments)
2. ✅ Update ALL RLS policies to use fixed permissions
3. ✅ Add documentation comments to tables
4. ✅ Verify RLS is enabled on all critical tables

**Note:** Existing `bestie_permissions` data is **not deleted** (kept for historical reference), but it's **no longer used** by the application.

### For New Databases

Use the updated `database_init.sql` which includes all fixed permission policies from the start.

---

## API Changes

### accept-invite.js

**Before:**
```javascript
const { invite_token, userToken, bestie_knowledge_permissions } = req.body;

// Create bestie_permissions entry
await supabaseAdmin.from('bestie_permissions').insert({
  bestie_user_id: user.id,
  inviter_user_id: invite.created_by,
  wedding_id: invite.wedding_id,
  permissions: bestie_knowledge_permissions
});
```

**After:**
```javascript
const { invite_token, userToken } = req.body;

// No longer create bestie_permissions entry
// Permissions are FIXED by role (hardcoded in RLS)
```

---

## UI Changes

### accept-invite-luxury.html

**Before:**
```html
<!-- Permission toggles -->
<input type="checkbox" id="bestieReadPermission">
<input type="checkbox" id="bestieEditPermission">
```

**After:**
```html
<!-- Privacy notice -->
<div id="bestiePrivacySection">
  <h3>🔒 Your Private Planning Space</h3>
  <p>Privacy Guarantee: The couple cannot see, edit, or even know your
     bestie planning exists. Your space is completely private.</p>
</div>
```

---

## AI Chat Context

The AI chat respects the same permissions:

### Owner/Partner Chat (message_type = 'main')
- ✅ Can read: `wedding_profiles`, `vendor_tracker`, `budget_tracker`, `wedding_tasks`
- ✅ Can write: Same as above
- ❌ Cannot read: `bestie_knowledge`, `bestie_profile`
- ❌ Cannot write: Bestie data

### Bestie Chat (message_type = 'bestie')
- ✅ Can read: `wedding_profiles` (for context), own `bestie_knowledge`, own `bestie_profile`
- ✅ Can write: Own `bestie_knowledge`, own `bestie_profile`
- ❌ Cannot read: `vendor_tracker`, `budget_tracker`, `wedding_tasks`, main chat, other besties' data
- ❌ Cannot write: `wedding_profiles`, any wedding planning data

**Example Bestie Query:**
> "The bride mentioned wanting a tropical theme. Can you help me plan bachelorette party activities that match?"

AI response:
- ✅ Reads `wedding_profiles.theme` = "tropical" (allowed)
- ✅ Suggests tropical bachelorette ideas
- ✅ Stores ideas in `bestie_knowledge` (allowed)
- ❌ Cannot access bride's main chat history
- ❌ Cannot see budget or vendor details

---

## Benefits of Fixed Permissions

### 1. Simplicity
- ❌ No confusing toggles
- ❌ No settings pages
- ❌ No "what should I choose?" anxiety
- ✅ Role tells you everything you need to know

### 2. Security
- ✅ Enforced at database level (RLS)
- ✅ Cannot be bypassed by UI bugs
- ✅ Clear privacy boundaries
- ✅ Each query is validated by Postgres

### 3. User Experience
- ✅ Matches user expectations
- ✅ Clear mental model (Owner/Partner = full, Bestie = view + private)
- ✅ No surprise access issues
- ✅ Privacy guarantee is trustworthy

### 4. Maintainability
- ✅ Fewer moving parts
- ✅ Simpler RLS policies
- ✅ Less code to maintain
- ✅ Easier to reason about

---

## Testing Checklist

### Test 1: Owner/Partner Cannot Access Bestie Data
- [ ] Owner tries to query `bestie_knowledge` → Returns 0 rows
- [ ] Partner tries to query `bestie_profile` → Returns 0 rows
- [ ] Owner tries to view bestie chat messages → Returns 0 rows

### Test 2: Bestie Cannot Edit Wedding Data
- [ ] Bestie tries to UPDATE `wedding_profiles` → Permission denied
- [ ] Bestie tries to INSERT into `vendor_tracker` → Permission denied
- [ ] Bestie tries to view main chat → Returns 0 rows

### Test 3: Bestie CAN View Wedding Data
- [ ] Bestie queries `wedding_profiles` → Can see wedding details
- [ ] Bestie sees date, venue, theme, colors → Success
- [ ] Bestie queries `wedding_members` → Can see team members

### Test 4: Bestie Data Isolation
- [ ] MOH creates knowledge entry
- [ ] Best Man queries `bestie_knowledge` → Cannot see MOH's entry
- [ ] Each bestie only sees their own data → Success

### Test 5: Chat Separation
- [ ] Owner sends message to main chat (message_type='main')
- [ ] Bestie queries chat_messages → Cannot see owner's message
- [ ] Bestie sends message to bestie chat (message_type='bestie')
- [ ] Owner queries chat_messages → Cannot see bestie's message

---

## Troubleshooting

### "Permission Denied" Error
**Cause:** User's role doesn't have access to that resource
**Solution:** Verify user's role in `wedding_members` table

### Bestie Can't See Wedding Details
**Cause:** RLS policy may not be updated
**Solution:** Run migration 022 to update policies

### Owner Seeing Bestie Data
**Cause:** RLS policies not properly configured
**Solution:** Check that `bestie_knowledge` policies only allow `bestie_user_id = auth.uid()`

---

## Summary

**Fixed Permissions = Simpler, Clearer, More Secure**

- ✅ Role-based access (Owner, Partner, Bestie)
- ✅ Fixed permissions (no toggles)
- ✅ Database-enforced (RLS policies)
- ✅ Clear privacy boundaries
- ✅ Matches user expectations

**Migration 022** removes manual permission system and implements fixed role-based access throughout the entire application.

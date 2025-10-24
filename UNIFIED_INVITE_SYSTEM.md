# Unified Invite System

**Implementation Date:** 2025-10-24
**Status:** Complete

## Overview

The Unified Invite System provides a single, consistent way to invite all wedding team members (partners, co-planners, and besties) using shareable one-time-use links.

## Key Features

✅ **One System for All Roles** - Partner, Co-planner, and Bestie invites work the same way
✅ **Shareable Links** - Owner generates link, copies it, and shares via any channel
✅ **One-Time Use** - Links expire after acceptance (can't be reused)
✅ **7-Day Expiration** - Links automatically expire 7 days after creation
✅ **Granular Permissions** - Control wedding profile read/edit access per invite
✅ **Bestie Privacy** - Bestie can control inviter's access to their knowledge
✅ **Secure Tokens** - Cryptographically random tokens prevent guessing

---

## Architecture

### Database Schema

**Table:** `invite_codes`

```sql
CREATE TABLE invite_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id),
  created_by UUID NOT NULL REFERENCES auth.users(id),
  role TEXT NOT NULL CHECK (role IN ('partner', 'co_planner', 'bestie')),
  invite_token TEXT NOT NULL UNIQUE,
  wedding_profile_permissions JSONB DEFAULT '{"read": false, "edit": false}',
  used BOOLEAN DEFAULT FALSE,
  used_by UUID REFERENCES auth.users(id),
  used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Key Changes from Old System:**
- ✅ Renamed `code` → `invite_token` (secure 32-byte token)
- ✅ Renamed `is_used` → `used` (consistency)
- ✅ Added `expires_at` (7-day expiration)
- ✅ Added `wedding_profile_permissions` (granular access control)
- ✅ Updated role constraint to include `partner`, `co_planner`, `bestie`

---

## API Endpoints

### 1. Create Invite Link

**Endpoint:** `POST /api/create-invite`

**Purpose:** Generate shareable invite link for any role

**Input:**
```json
{
  "userToken": "jwt-token",
  "role": "partner | co_planner | bestie",
  "wedding_profile_permissions": {
    "read": true,
    "edit": false
  }
}
```

**Output:**
```json
{
  "success": true,
  "invite_url": "https://bridebuddyv2.vercel.app/accept-invite.html?token=abc123...",
  "invite_token": "abc123...",
  "role": "co_planner",
  "wedding_profile_permissions": { "read": true, "edit": false },
  "expires_at": "2025-10-31T12:00:00Z",
  "wedding_name": "Alice & Bob",
  "message": "Co-planner invite link created successfully"
}
```

**Security:**
- ✅ Only wedding owners can create invites
- ✅ Generates cryptographically secure 32-byte token
- ✅ Sets expiration to exactly 7 days from creation

---

### 2. Get Invite Info

**Endpoint:** `GET /api/get-invite-info?invite_token=abc123`

**Purpose:** Validate token and display invite details (public endpoint)

**Output:**
```json
{
  "success": true,
  "is_valid": true,
  "invite": {
    "wedding_name": "Alice & Bob",
    "wedding_date": "2025-12-25",
    "inviter_name": "Alice Smith",
    "role": "co_planner",
    "role_display": "Co-planner",
    "wedding_profile_permissions": { "read": true, "edit": false },
    "created_at": "2025-10-24T12:00:00Z",
    "expires_at": "2025-10-31T12:00:00Z",
    "days_until_expiration": 7,
    "hours_until_expiration": 168
  },
  "permissions": {
    "can_read_wedding_profile": true,
    "can_edit_wedding_profile": false
  }
}
```

**Error Cases:**
- `404` - Invalid token
- `400` - Already used: `{ "error": "This invite has already been used", "is_used": true }`
- `400` - Expired: `{ "error": "This invite has expired", "is_expired": true }`

**Security:**
- ✅ Accessible without authentication (for new users)
- ✅ Returns minimal info (no sensitive wedding data)
- ✅ Checks expiration and usage status

---

### 3. Accept Invite

**Endpoint:** `POST /api/accept-invite`

**Purpose:** Accept invite and join wedding team

**Input:**
```json
{
  "invite_token": "abc123...",
  "userToken": "jwt-token",
  "bestie_knowledge_permissions": {
    "can_read": false,
    "can_edit": false
  }
}
```

**Note:** `bestie_knowledge_permissions` only used for bestie role (controls inviter's access to bestie's private knowledge)

**Output:**
```json
{
  "success": true,
  "message": "Successfully joined as co-planner!",
  "wedding": {
    "id": "uuid",
    "name": "Alice & Bob",
    "date": "2025-12-25"
  },
  "your_role": "co_planner",
  "permissions": {
    "wedding_profile": { "read": true, "edit": false }
  },
  "redirect_to": "/dashboard-v2.html?wedding_id=uuid",
  "next_steps": [
    "You have view-only access to this wedding",
    "You can help plan and coordinate details",
    "You can request changes through the couple",
    "Welcome to the planning team!"
  ]
}
```

**Security:**
- ✅ Requires authentication
- ✅ Validates token is unused and not expired
- ✅ Checks user isn't already a member
- ✅ Enforces 1:1 bestie-inviter relationship
- ✅ Marks invite as used (prevents reuse)

**Database Operations:**
1. Add to `wedding_members` with role and permissions
2. If bestie: Create `bestie_permissions` record
3. Mark invite as `used=true` with `used_by` and `used_at`

---

## Frontend Pages

### 1. Invite Creation Page

**File:** `public/invite-v2.html`

**Features:**
- Select role (partner, co-planner, bestie)
- Set wedding profile permissions (read/edit)
- Generate invite link
- Copy link to clipboard
- View all active invite links
- View current team members

**Changes from Old System:**
- ❌ Removed: Name and email fields (not needed for link-based invites)
- ✅ Added: Copy link button
- ✅ Added: Expiration countdown
- ✅ Added: Permission toggles for all roles
- ✅ Updated: Shows full invite URL instead of short code

---

### 2. Invite Acceptance Page

**File:** `public/accept-invite.html`

**Features:**
- Validates invite token on page load
- Displays wedding details and inviter name
- Shows role and permissions
- Shows expiration countdown
- For besties: Permission toggles for inviter's access
- Sign up / log in prompts for new users
- One-click acceptance for logged-in users
- Auto-redirect to dashboard after acceptance

**User Flow:**
1. User clicks invite link
2. Page validates token via `/api/get-invite-info`
3. If invalid/expired: Show error
4. If valid: Display invite details
5. If not logged in: Show signup/login buttons
6. If logged in: Show "Accept Invitation" button
7. On accept: Call `/api/accept-invite`
8. On success: Redirect to dashboard

---

## Migration Guide

### Step 1: Deploy Database Migration

Run migration file: `migrations/006_unified_invite_system.sql`

This will:
- Add `invite_token`, `expires_at`, `wedding_profile_permissions` columns
- Migrate existing invite codes to new format
- Update role constraints
- Create helper functions and indexes
- Set up RLS policies

### Step 2: Deploy API Endpoints

New/Updated files:
- `api/create-invite.js` - Rewritten for unified system
- `api/get-invite-info.js` - New endpoint
- `api/accept-invite.js` - New endpoint (replaces role-specific endpoints)

### Step 3: Deploy Frontend Pages

Updated files:
- `public/invite-v2.html` - Rewritten for link-based invites
- `public/accept-invite.html` - New page

### Step 4: Deprecate Old Endpoints (Optional)

Old endpoints to deprecate:
- `api/create-bestie-invite.js` - Replaced by unified `create-invite`
- `api/accept-bestie-invite.js` - Replaced by unified `accept-invite`

**Note:** Keep old endpoints for backward compatibility if needed, or add deprecation warnings.

---

## User Flows

### Flow 1: Partner Invite

1. **Owner creates partner invite:**
   - Select role: "Partner (Full Edit Access)"
   - Permissions automatically set to read=true, edit=true (locked)
   - Click "Generate Invite Link"
   - Copy link: `https://bridebuddyv2.vercel.app/accept-invite.html?token=abc123`

2. **Owner shares link:**
   - Text message, email, or any messaging app
   - "Hey! Here's your invite to plan our wedding together: [link]"

3. **Partner accepts:**
   - Clicks link
   - Sees: "You've been invited to join [Wedding] as Partner"
   - Signs up or logs in
   - Clicks "Accept Invitation"
   - Redirected to dashboard with full access

### Flow 2: Co-planner Invite

1. **Owner creates co-planner invite:**
   - Select role: "Co-planner"
   - Set permissions: read=true, edit=false
   - Generate and copy link

2. **Co-planner accepts:**
   - Sees: "You've been invited as Co-planner"
   - Permissions shown: "Can view wedding details ✓, Can edit ✗"
   - Accepts and gets view-only access

### Flow 3: Bestie Invite

1. **Owner creates bestie invite:**
   - Select role: "Bestie (MOH/Best Man)"
   - Set wedding permissions: read=true, edit=false
   - Generate and copy link

2. **Bestie accepts:**
   - Sees: "You've been invited as Bestie"
   - **Additional step:** Set inviter's access to bestie knowledge
     - Toggle: "Allow inviter to view my bestie knowledge" (default: off)
     - Toggle: "Allow inviter to edit my bestie knowledge" (default: off)
   - Accepts invitation
   - Gets private bestie planning space
   - Inviter can only access bestie knowledge if permission granted

---

## Permission Matrix

### Wedding Profile Access (Set by Owner)

| Role       | Default Read | Default Edit | Can Change? |
|------------|--------------|--------------|-------------|
| Partner    | ✓            | ✓            | No (locked) |
| Co-planner | ✓            | ✗            | Yes         |
| Bestie     | ✗            | ✗            | Yes         |

### Bestie Knowledge Access (Set by Bestie)

| Permission  | Default | Meaning                                    |
|-------------|---------|-------------------------------------------|
| can_read    | ✗       | Inviter can view bestie's planning notes  |
| can_edit    | ✗       | Inviter can edit bestie's planning notes  |

**Privacy by Default:** Inviter has no access to bestie knowledge unless explicitly granted.

---

## Security Considerations

### Token Security

✅ **Cryptographically Random:** Uses `crypto.randomBytes(32)` for unpredictable tokens
✅ **Base64URL Encoding:** URL-safe tokens (no special characters)
✅ **Unique Constraint:** Database enforces token uniqueness
✅ **Length:** 43 characters (256 bits of entropy)

### Expiration

✅ **7-Day Limit:** All invites expire after 7 days
✅ **Database Enforced:** `expires_at` checked in API and database functions
✅ **Cleanup Function:** `cleanup_expired_invites()` removes old invites (30+ days)

### One-Time Use

✅ **Marked as Used:** `used=true` set immediately on acceptance
✅ **Used By Tracking:** Records which user accepted
✅ **Used At Timestamp:** Records when invite was accepted
✅ **API Validation:** All endpoints check `used` status

### Authorization

✅ **Owner-Only Creation:** Only wedding owners can create invites
✅ **RLS Policies:** Row-level security on invite_codes table
✅ **Authentication Required:** Accept endpoint requires valid user token
✅ **Membership Check:** Prevents duplicate memberships

---

## Troubleshooting

### Problem: Invite link shows "Invalid"

**Possible causes:**
- Token was mistyped or truncated
- Invite was already used
- Invite expired (>7 days old)

**Solution:**
- Generate new invite link
- Share complete URL (don't truncate)

### Problem: "Already a member" error

**Cause:** User already accepted invite to this wedding

**Solution:** User should log in with existing account

### Problem: Bestie 1:1 constraint error

**Cause:** Inviter already has a bestie for this wedding

**Solution:** Each person can only have one bestie per wedding. Generate new invite or remove existing bestie first.

### Problem: Permissions not working

**Check:**
- `wedding_profile_permissions` in `wedding_members` table
- `bestie_permissions` table for bestie-specific access
- RLS policies on relevant tables

---

## Database Indexes

For optimal performance:

```sql
-- Fast token lookup
CREATE INDEX invite_codes_invite_token_idx ON invite_codes(invite_token)
  WHERE used IS NULL OR used = false;

-- Expiration cleanup
CREATE INDEX invite_codes_expires_at_idx ON invite_codes(expires_at);

-- Valid invites query
CREATE INDEX invite_codes_valid_idx ON invite_codes(invite_token, expires_at)
  WHERE used IS NULL OR used = false;
```

---

## Monitoring

### Key Metrics to Track

- **Invite Acceptance Rate:** % of generated invites that get accepted
- **Time to Accept:** How long between creation and acceptance
- **Expired Invites:** % of invites that expire unused
- **Role Distribution:** Partner vs Co-planner vs Bestie invites

### Database Queries

```sql
-- Count active invites by role
SELECT role, COUNT(*)
FROM invite_codes
WHERE (used = false OR used IS NULL)
  AND expires_at > NOW()
GROUP BY role;

-- Count expired unused invites
SELECT COUNT(*)
FROM invite_codes
WHERE (used = false OR used IS NULL)
  AND expires_at < NOW();

-- Acceptance rate
SELECT
  COUNT(*) FILTER (WHERE used = true) * 100.0 / COUNT(*) AS acceptance_rate
FROM invite_codes;
```

---

## Future Enhancements

### Potential Features

1. **Custom Expiration:** Allow owner to set expiration (1-30 days)
2. **Invite Revocation:** Cancel pending invite before acceptance
3. **Email Sending:** Auto-send invite via email (optional)
4. **Invite Templates:** Save common permission sets
5. **Bulk Invites:** Generate multiple invites at once
6. **Analytics Dashboard:** Track invite performance
7. **Invite Reminders:** Notify user if invite expires soon

---

## API Examples

### Create Partner Invite

```javascript
const response = await fetch('/api/create-invite', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    userToken: session.access_token,
    role: 'partner',
    wedding_profile_permissions: { read: true, edit: true }
  })
});

const data = await response.json();
// data.invite_url: "https://bridebuddyv2.vercel.app/accept-invite.html?token=..."
```

### Check Invite Validity

```javascript
const token = 'abc123...';
const response = await fetch(`/api/get-invite-info?invite_token=${token}`);
const data = await response.json();

if (data.is_valid) {
  console.log(`Valid invite for ${data.invite.wedding_name} as ${data.invite.role_display}`);
} else {
  console.log(`Invalid: ${data.error}`);
}
```

### Accept Invite

```javascript
const response = await fetch('/api/accept-invite', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    invite_token: 'abc123...',
    userToken: session.access_token,
    bestie_knowledge_permissions: { can_read: false, can_edit: false }
  })
});

const data = await response.json();
// Redirect to: data.redirect_to
```

---

## Conclusion

The Unified Invite System provides a simple, secure, and consistent way to invite all wedding team members. By using shareable links instead of codes, it reduces friction and matches modern user expectations. The granular permission system ensures proper access control while maintaining privacy for bestie planning.

---

**Documentation Version:** 1.0
**Last Updated:** 2025-10-24
**Implementation Status:** ✅ Complete

# CO-PLANNER INVITE SYSTEM FLOW ANALYSIS

**Analysis Date:** 2025-10-24
**Purpose:** Map out current co-planner invite system to understand the flow and identify gaps

---

## ⚠️ CRITICAL FINDING: SYSTEM MISMATCH

The current co-planner invite system has a **DISCONNECT** between the UI and API:

- **UI (invite-v2.html):** Expects to send email invites with names and emails
- **API (api/create-invite.js):** Original was broken proxy, current generates codes only
- **Result:** UI and API don't match - system is incomplete

---

## STEP-BY-STEP FLOW ANALYSIS

### STEP 1: Owner Creates Invite (UI)

**File:** `public/invite-v2.html`

**UI Elements:**
```html
<!-- Lines 25-57 -->
<form id="inviteForm" onsubmit="sendInvite(event)">
    <input type="text" id="inviteeName" placeholder="Jane Doe" required>
    <input type="email" id="inviteeEmail" placeholder="jane@example.com" required>
    <select id="inviteeRole" required>
        <option value="partner">Partner (Full Edit Access)</option>
        <option value="co_planner">Co-planner (View + Request Changes)</option>
        <option value="bestie">Bestie (MOH/Best Man)</option>
    </select>
    <!-- Edit permission checkbox appears for co_planner role -->
    <input type="checkbox" id="canEdit">
</form>
```

**Data Collected:**
- `inviteeName` - Co-planner's name
- `inviteeEmail` - Co-planner's email
- `role` - partner | co_planner | bestie
- `canEdit` - boolean (only for co_planner role)

**JavaScript Call:**
```javascript
// Lines 116-128
async function sendInvite(event) {
    const response = await fetch('/api/create-invite', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            wedding_id: weddingId,
            invitee_name: name,
            invitee_email: email,
            role: role,
            can_edit: canEdit
        })
    });

    // Line 133 - Shows success message
    alert(`Invite sent to ${name}! They'll receive an email with a link to join.`);
}
```

**Expected Behavior:**
- Form submits invitee details
- API sends EMAIL to invitee
- Success message says "they'll receive an email"

---

### STEP 2: Create Invite API (BROKEN)

**File:** `api/create-invite.js`

**ORIGINAL Implementation (Before Fix):**
```javascript
export default async function handler(req, res) {
  const { userToken, role = 'member' } = req.body;

  // Proxies to non-existent Supabase Edge Function
  const response = await fetch(
    'https://nluvnjydydotsrpluhey.supabase.co/functions/v1/create-invite',  // ❌ Doesn't exist
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${userToken}`,
        'apikey': 'eyJhbGci...'
      },
      body: JSON.stringify({ userToken, role })
    }
  );
}
```

**Problems:**
1. ❌ Expects `userToken` and `role` - UI sends different parameters
2. ❌ Calls non-existent Supabase Edge Function
3. ❌ No email sending functionality
4. ❌ No support for `wedding_id`, `invitee_name`, `invitee_email`, `can_edit`

**CURRENT Implementation (After Fix - Phase 2):**
```javascript
// api/create-invite.js (lines 1-138)
export default async function handler(req, res) {
  const { userToken, role = 'member' } = req.body;  // ⚠️ Still doesn't match UI

  // Generates 8-character invite code
  const inviteCode = generateInviteCode();  // Returns: "ABC23456"

  // Stores in database
  await supabaseAdmin
    .from('invite_codes')
    .insert({
      wedding_id: membership.wedding_id,
      code: inviteCode,
      created_by: user.id,
      role: role,
      is_used: false
    });

  return res.status(200).json({
    success: true,
    inviteCode: invite.code  // Returns code, not email confirmation
  });
}
```

**Current Problems:**
1. ⚠️ Generates CODE instead of sending EMAIL
2. ⚠️ Expects different parameters than UI sends
3. ⚠️ No email sending functionality
4. ⚠️ Doesn't store invitee_name, invitee_email, can_edit

---

### STEP 3: What SHOULD Happen (Missing)

**Missing Implementation:**

```javascript
// What api/create-invite.js SHOULD do to match UI:
export default async function handler(req, res) {
  const {
    wedding_id,      // ✅ From UI
    invitee_name,    // ✅ From UI
    invitee_email,   // ✅ From UI
    role,            // ✅ From UI
    can_edit         // ✅ From UI
  } = req.body;

  // Generate invite token
  const inviteToken = generateSecureToken();  // UUID or JWT

  // Store in database
  await supabaseAdmin
    .from('invite_codes')
    .insert({
      wedding_id: wedding_id,
      invitee_name: invitee_name,      // ❌ Column doesn't exist
      invitee_email: invitee_email,    // ❌ Column doesn't exist
      code: inviteToken,
      created_by: user.id,
      role: role,
      can_edit: can_edit,              // ❌ Column doesn't exist
      is_used: false
    });

  // Send email with invite link
  await sendEmail({
    to: invitee_email,
    subject: 'You\'re invited to help plan a wedding!',
    body: `
      Hi ${invitee_name},

      You've been invited to help plan a wedding!
      Click here to accept: https://bridebuddyv2.vercel.app/accept-invite?token=${inviteToken}
    `
  });

  return res.json({ success: true });
}
```

---

### STEP 4: Invite Database Storage

**Table:** `invite_codes`

**Current Columns:**
```sql
-- From create_missing_tables.sql (lines 72-81)
CREATE TABLE invite_codes (
  id UUID PRIMARY KEY,
  wedding_id UUID REFERENCES wedding_profiles(id),
  code TEXT UNIQUE,           -- Invite code/token
  created_by UUID REFERENCES auth.users(id),
  role TEXT,                  -- ✅ Stores role
  is_used BOOLEAN,
  used_by UUID,
  created_at TIMESTAMPTZ,
  used_at TIMESTAMPTZ
);
```

**Missing Columns:**
```sql
-- What's needed for email-based invites:
invitee_name TEXT          -- ❌ Missing
invitee_email TEXT         -- ❌ Missing
can_edit BOOLEAN           -- ❌ Missing
```

**What Gets Stored (Current):**
```javascript
{
  wedding_id: "uuid",
  code: "ABC23456",        // 8-character code
  created_by: "owner_id",
  role: "bestie",          // or "member"
  is_used: false
}
```

**What SHOULD Be Stored:**
```javascript
{
  wedding_id: "uuid",
  code: "secure-token-or-uuid",
  invitee_name: "Jane Doe",      // ❌ Not stored currently
  invitee_email: "jane@example.com",  // ❌ Not stored currently
  created_by: "owner_id",
  role: "co_planner",            // or "partner" or "bestie"
  can_edit: true,                // ❌ Not stored currently
  is_used: false
}
```

---

### STEP 5: Invite Acceptance (MISSING ENTIRELY)

**Expected Flow:**
1. Co-planner receives email
2. Clicks link: `https://bridebuddyv2.vercel.app/accept-invite?token=ABC123`
3. Lands on accept page
4. Signs up or logs in
5. API processes acceptance

**Current Reality:**
- ❌ No email sending functionality
- ❌ No `accept-invite.html` page exists
- ❌ No `/api/accept-invite` endpoint exists (only `/api/join-wedding` which expects invite CODE)

**Files That DON'T Exist:**
- `public/accept-invite.html` - Missing
- `api/accept-invite.js` - Missing (only `/api/accept-bestie-invite` for besties)

---

### STEP 6: Join Wedding API

**File:** `api/join-wedding.js`

**Current Implementation:**
```javascript
// Lines 1-152
export default async function handler(req, res) {
  const { inviteCode, userToken } = req.body;

  // Look up invite by code
  const { data: invite } = await supabaseAdmin
    .from('invite_codes')
    .select('*')
    .eq('code', inviteCode.toUpperCase())
    .eq('is_used', false)
    .single();

  if (!invite) {
    return res.status(404).json({ error: 'Invalid or already used invite' });
  }

  // Add user to wedding_members
  await supabaseAdmin
    .from('wedding_members')
    .insert({
      wedding_id: invite.wedding_id,
      user_id: user.id,
      role: invite.role  // 'member' or 'bestie'
    });

  // Mark invite as used
  await supabaseAdmin
    .from('invite_codes')
    .update({
      is_used: true,
      used_by: user.id,
      used_at: new Date().toISOString()
    })
    .eq('code', inviteCode);

  return res.json({ success: true, weddingId: invite.wedding_id });
}
```

**How It Works:**
- ✅ Accepts invite code (e.g., "ABC23456")
- ✅ Validates code exists and is unused
- ✅ Adds user to `wedding_members` with role from invite
- ✅ Marks invite as used

**What's Missing:**
- ❌ No support for `can_edit` permission
- ❌ No support for email-based token validation
- ❌ Doesn't verify invitee email matches

---

### STEP 7: Current Permission Handling

**Where Permissions Are Set:**

**In invite-v2.html (UI):**
```javascript
// Lines 96-101
if (role === 'co_planner') {
    // Show edit permission checkbox
    editGroup.classList.remove('hidden');
}

const canEdit = role === 'co_planner' ? document.getElementById('canEdit').checked : false;
```

**In Database:**
- ❌ `can_edit` is NOT stored in `invite_codes` table
- ❌ `can_edit` is NOT stored in `wedding_members` table
- ❌ Permission is lost - UI collects it but nowhere stores it

**Permission Options (From UI):**
```javascript
// Lines 40-43
{
  "partner": "Full Edit Access",         // Auto can_edit = true
  "co_planner": "View + Request Changes",  // can_edit = user choice
  "bestie": "MOH/Best Man"               // Special role
}
```

---

## PERMISSION DATA STRUCTURE (Current vs Needed)

**Current - NO PERMISSIONS:**
```sql
-- wedding_members table doesn't track permissions
wedding_id UUID
user_id UUID
role TEXT  -- Just "owner", "member", "bestie"
```

**Needed - WITH PERMISSIONS:**
```sql
-- wedding_members should have:
wedding_id UUID
user_id UUID
role TEXT  -- "owner", "partner", "co_planner", "bestie"
can_edit BOOLEAN  -- Permission flag
invited_by_user_id UUID  -- ✅ Added in Phase 1
wedding_profile_permissions JSONB  -- ✅ Added in Phase 1
```

---

## COMPLETE FLOW DIAGRAM (What Should Exist)

### IDEAL CO-PLANNER INVITE FLOW:

```
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: Owner Creates Invite                                    │
├─────────────────────────────────────────────────────────────────┤
│ File: public/invite-v2.html                                     │
│                                                                 │
│ Form Fields:                                                    │
│   - Name: "Jane Doe"                                           │
│   - Email: "jane@example.com"                                  │
│   - Role: "co_planner"                                         │
│   - Can Edit: [✓] (checkbox)                                   │
│                                                                 │
│ Button Click: "Send Invite"                                    │
│                                                                 │
│ API Call:                                                       │
│   POST /api/create-invite                                       │
│   {                                                             │
│     wedding_id: "uuid",                                        │
│     invitee_name: "Jane Doe",                                  │
│     invitee_email: "jane@example.com",                         │
│     role: "co_planner",                                        │
│     can_edit: true                                             │
│   }                                                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: API Processes Invite                                    │
├─────────────────────────────────────────────────────────────────┤
│ File: api/create-invite.js                                      │
│                                                                 │
│ Actions:                                                        │
│   1. Authenticate owner                                         │
│   2. Generate secure token (UUID or JWT)                       │
│   3. Store in database                                          │
│   4. Send email to invitee                                     │
│                                                                 │
│ Database Insert:                                                │
│   INSERT INTO invite_codes (                                    │
│     wedding_id, code, invitee_name,                            │
│     invitee_email, role, can_edit, created_by                  │
│   ) VALUES (                                                    │
│     'uuid', 'secure-token-123',                                │
│     'Jane Doe', 'jane@example.com',                            │
│     'co_planner', true, 'owner_id'                             │
│   );                                                            │
│                                                                 │
│ Email Sent:                                                     │
│   To: jane@example.com                                         │
│   Link: https://.../accept-invite?token=secure-token-123       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: Co-planner Receives Email                              │
├─────────────────────────────────────────────────────────────────┤
│ Email Content:                                                  │
│   "Hi Jane Doe,                                                │
│    You've been invited to help plan a wedding!                 │
│    Click here to accept: [Link]"                               │
│                                                                 │
│ Link: https://bridebuddyv2.vercel.app/accept-invite            │
│       ?token=secure-token-123                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 4: Co-planner Clicks Link                                 │
├─────────────────────────────────────────────────────────────────┤
│ File: public/accept-invite.html (❌ DOESN'T EXIST)             │
│                                                                 │
│ Page Shows:                                                     │
│   "You've been invited to help plan [Couple's Names] wedding!" │
│   "Sign up or log in to get started"                          │
│                                                                 │
│ Buttons:                                                        │
│   [Create Account] or [Log In]                                │
│                                                                 │
│ URL Params:                                                     │
│   ?token=secure-token-123                                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 5: Co-planner Signs Up/Logs In                            │
├─────────────────────────────────────────────────────────────────┤
│ After Authentication:                                           │
│   Auto-call /api/accept-invite                                 │
│                                                                 │
│ API Call:                                                       │
│   POST /api/accept-invite                                       │
│   {                                                             │
│     token: "secure-token-123",                                 │
│     userToken: "authenticated-user-jwt"                        │
│   }                                                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 6: API Processes Acceptance                               │
├─────────────────────────────────────────────────────────────────┤
│ File: api/accept-invite.js (❌ DOESN'T EXIST)                  │
│                                                                 │
│ Actions:                                                        │
│   1. Validate token                                             │
│   2. Get invite details from database                          │
│   3. Verify user email matches invitee_email                   │
│   4. Add user to wedding_members                               │
│   5. Mark invite as used                                       │
│                                                                 │
│ Database Insert:                                                │
│   INSERT INTO wedding_members (                                 │
│     wedding_id, user_id, role,                                 │
│     can_edit, invited_by_user_id                               │
│   ) VALUES (                                                    │
│     'uuid', 'user-id', 'co_planner',                           │
│     true, 'owner-id'                                           │
│   );                                                            │
│                                                                 │
│ Redirect:                                                       │
│   → dashboard-v2.html?wedding_id=uuid                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## CURRENT SYSTEM STATUS

### ✅ What Works:
1. UI for creating invites (invite-v2.html)
2. Displaying pending invites
3. Displaying current members
4. `/api/join-wedding` can process invite codes

### ❌ What's Broken/Missing:
1. `/api/create-invite` doesn't match UI expectations
2. No email sending functionality
3. No invite acceptance page (`accept-invite.html`)
4. No `/api/accept-invite` endpoint for co-planners
5. `invite_codes` table missing columns: `invitee_name`, `invitee_email`, `can_edit`
6. `wedding_members` table missing column: `can_edit`
7. Permissions collected by UI but never stored
8. No email validation on acceptance

---

## RECOMMENDED FIXES

### Fix 1: Update `invite_codes` Schema
```sql
ALTER TABLE invite_codes
  ADD COLUMN invitee_name TEXT,
  ADD COLUMN invitee_email TEXT,
  ADD COLUMN can_edit BOOLEAN DEFAULT false;
```

### Fix 2: Update `wedding_members` Schema
```sql
ALTER TABLE wedding_members
  ADD COLUMN can_edit BOOLEAN DEFAULT false;
```

### Fix 3: Rewrite `/api/create-invite`
Match UI expectations:
- Accept `wedding_id`, `invitee_name`, `invitee_email`, `role`, `can_edit`
- Generate secure token
- Store all fields in database
- Send email with invite link

### Fix 4: Create `/api/accept-invite`
- Validate token
- Verify email matches
- Add user to wedding_members with permissions
- Mark invite as used

### Fix 5: Create `public/accept-invite.html`
- Show invite details
- Handle signup/login
- Auto-accept after authentication

---

## COMPARISON TO BESTIE SYSTEM

### Bestie System (Phase 2 - Complete):
✅ `/api/create-bestie-invite` - Creates invite with permissions
✅ `/api/accept-bestie-invite` - Accepts invite and establishes relationship
✅ Stores permissions in database
✅ Enforces 1:1 relationship
✅ Returns comprehensive status

### Co-Planner System (Current - Incomplete):
❌ `/api/create-invite` - Doesn't match UI
❌ No accept endpoint
❌ Doesn't store permissions
❌ No email functionality
❌ UI and API mismatch

---

**End of Analysis**

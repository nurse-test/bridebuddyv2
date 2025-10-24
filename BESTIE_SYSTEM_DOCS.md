# Bestie Chat System Documentation

## Overview

The Bestie Chat is a dedicated AI assistant for the **Maid of Honor, Best Man, or Best Friend** helping with wedding events and bridal party coordination. It's separate from the main wedding planning chat used by the bride/groom.

---

## Current Status

### ✅ What's Working

**1. Database Schema:**
- `chat_messages` table supports `message_type` IN ('main', 'bestie') ✅
- `wedding_members` table has `role` column for user roles ✅
- RLS policies allow users to see messages for their weddings ✅

**2. API Endpoints:**
- `/api/bestie-chat.js` - Handles bestie AI chat ✅
  - Checks authentication
  - Verifies trial/VIP status
  - Saves with `message_type='bestie'`
  - Uses MOH/Best Man specific AI personality
- Correct AI context for MOH/Best Man duties ✅

**3. Frontend:**
- `bestie-v2.html` - Bestie chat interface ✅
  - Checks `bestie_addon_enabled` on wedding
  - Verifies user has `role='bestie'` OR `role='owner'`
  - Loads only bestie chat history (`message_type='bestie'`)
  - Separate UI from main planning chat

**4. Trial/Payment:**
- Free trial automatically includes `bestie_addon_enabled: true` ✅
- Bestie button shows on dashboard when enabled ✅
- Pay modal triggers on day 5 of trial ✅

---

## ⚠️ What Needs Setup

### 1. Database Constraints

**Run `setup_bestie_functionality.sql`** to ensure:
- `wedding_members.role` check includes: 'owner', 'member', 'bestie'
- `invite_codes.role` column exists and supports: 'member', 'bestie'
- All constraints are properly enforced

### 2. Supabase Edge Functions

You have placeholder APIs that call Supabase Edge Functions:
- `/api/create-invite.js` → calls Edge Function at `functions/v1/create-invite`
- `/api/join-wedding.js` → calls Edge Function at `functions/v1/join-wedding`

**These Edge Functions need to:**

**create-invite:**
```javascript
// Accept role parameter
const { userToken, role = 'member' } = req.body;

// Create invite code
const { data: invite, error } = await supabase
  .from('invite_codes')
  .insert({
    wedding_id: user_wedding_id,
    code: generateCode(),
    created_by: user.id,
    role: role  // 'member' or 'bestie'
  });

// Return invite code
```

**join-wedding:**
```javascript
// Look up invite code
const { data: invite } = await supabase
  .from('invite_codes')
  .select('*')
  .eq('code', inviteCode)
  .single();

// Add user to wedding with the specified role
await supabase
  .from('wedding_members')
  .insert({
    wedding_id: invite.wedding_id,
    user_id: user.id,
    role: invite.role  // Use role from invite
  });

// Mark invite as used
```

---

## Complete Bestie Invite Flow

### Step 1: Bride/Groom Creates Bestie Invite

**Frontend:**
```javascript
// On invite-v2.html or dashboard
async function createBestieInvite() {
  const { data: { session } } = await supabase.auth.getSession();

  const response = await fetch('/api/create-invite', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userToken: session.access_token,
      role: 'bestie'  // Specify bestie role
    })
  });

  const { inviteCode } = await response.json();
  // Show invite code to user to share
}
```

### Step 2: MOH/Best Man Signs Up

1. Goes to `welcome-v2.html`
2. Clicks "Start Your Wedding" (even though they're not creating their own)
3. OR there should be a "Join a Wedding" flow

### Step 3: MOH/Best Man Uses Invite Code

**Frontend:**
```javascript
// On invite-v2.html
async function joinAsbestie() {
  const { data: { session } } = await supabase.auth.getSession();

  const response = await fetch('/api/join-wedding', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      inviteCode: code,
      userToken: session.access_token
    })
  });

  // If successful, redirect to dashboard
  window.location.href = `dashboard-v2.html?wedding_id=${weddingId}`;
}
```

### Step 4: MOH/Best Man Accesses Bestie Chat

1. Dashboard loads
2. `bestie_addon_enabled: true` → Shows "Bestie Planning" button
3. Frontend checks `member.role === 'bestie'` → Allows access
4. Click "Bestie Planning" → Goes to `bestie-v2.html`
5. Chat with AI about bachelorette parties, bridal showers, etc.

---

## AI Personalities

### Main Chat (`/api/chat.js`)
**For:** Bride & Groom
**Purpose:** Wedding planning logistics
**Extracts:** Budget, venue, date, guest count → Updates database
**Tone:** Professional, organized, task-focused

### Bestie Chat (`/api/bestie-chat.js`)
**For:** Maid of Honor / Best Man
**Purpose:** Pre-wedding events and bridal party coordination
**Helps With:**
- Bachelorette/bachelor party planning
- Bridal shower coordination
- Engagement party planning
- Bridesmaid dress shopping
- Managing bridal party expenses
- Rehearsal dinner planning
- MOH/Best Man speech advice

**Tone:** Friendly, practical, organized, budget-conscious

---

## Database Schema Reference

### wedding_members
```sql
CREATE TABLE wedding_members (
  wedding_id UUID REFERENCES wedding_profiles(id),
  user_id UUID REFERENCES auth.users(id),
  role TEXT CHECK (role IN ('owner', 'member', 'bestie')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### invite_codes
```sql
CREATE TABLE invite_codes (
  id UUID PRIMARY KEY,
  wedding_id UUID REFERENCES wedding_profiles(id),
  code TEXT UNIQUE,
  created_by UUID REFERENCES auth.users(id),
  role TEXT DEFAULT 'member' CHECK (role IN ('member', 'bestie')),
  is_used BOOLEAN DEFAULT FALSE,
  used_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### chat_messages
```sql
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY,
  wedding_id UUID REFERENCES wedding_profiles(id),
  user_id UUID REFERENCES auth.users(id),
  message TEXT NOT NULL,
  role TEXT CHECK (role IN ('user', 'assistant')),
  message_type TEXT CHECK (message_type IN ('main', 'bestie')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Testing Checklist

- [ ] Run `setup_bestie_functionality.sql` in Supabase
- [ ] Update Supabase Edge Functions (create-invite, join-wedding)
- [ ] Test creating invite with role='bestie'
- [ ] Test joining wedding with bestie invite code
- [ ] Verify wedding_members has role='bestie' after join
- [ ] Access bestie-v2.html and verify it loads
- [ ] Send bestie chat message and verify it saves with message_type='bestie'
- [ ] Verify bestie messages don't appear in main chat
- [ ] Verify main chat messages don't appear in bestie chat
- [ ] Test trial expiration in bestie chat
- [ ] Test upgrade flow from bestie chat

---

## Current Gaps to Fill

1. **Supabase Edge Functions** - Need to implement role-based invites
2. **Frontend Invite UI** - Need UI to create bestie invite vs regular invite
3. **Join Flow** - Need better "Join a Wedding" flow for MOH/Best Man
4. **Role Management UI** - Admin panel to change user roles
5. **Multiple Besties** - Should support multiple MOH/bridesmaids with bestie role?

---

## Quick Start for Testing

**Manual Database Setup:**
```sql
-- Manually add a user as bestie
UPDATE wedding_members
SET role = 'bestie'
WHERE user_id = 'YOUR_USER_ID'
AND wedding_id = 'YOUR_WEDDING_ID';

-- Verify
SELECT * FROM wedding_members WHERE role = 'bestie';
```

Then access `bestie-v2.html?wedding_id=YOUR_WEDDING_ID` and test!

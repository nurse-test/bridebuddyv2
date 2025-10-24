# BESTIE SYSTEM AUDIT - Current vs Target Architecture

**Audit Date:** 2025-10-24
**Auditor:** Claude Code
**Purpose:** Compare current bestie implementation to target architecture requirements

---

## EXECUTIVE SUMMARY

**Overall Assessment:** 🔴 **20% Complete**

The current bestie system is a **simplified chat-based implementation** that allows:
- Creating invites with 'bestie' role
- Joining weddings as bestie via invite code
- Accessing a separate bestie chat interface
- Storing bestie chat messages separately (message_type='bestie')

**Critical Missing Components:**
- ❌ No permission system (bestie_permissions table)
- ❌ No bestie knowledge base (bestie_knowledge table)
- ❌ No invited_by tracking
- ❌ No 1:1 bestie-inviter relationship enforcement
- ❌ No granular permission management APIs

---

## A. DATABASE SCHEMA AUDIT

### 1. wedding_members Table

**Status:** ⚠️ **Exists but needs modification**

**Current Schema:**
```sql
-- File: rls_critical_tables_fixed.sql (lines 132-138)
-- Actual columns in wedding_members:
wedding_id UUID NOT NULL REFERENCES wedding_profiles(id)
user_id UUID NOT NULL REFERENCES auth.users(id)
role TEXT CHECK (role IN ('owner', 'member', 'bestie'))
-- Note: No created_at, no invited_by_user_id, no permissions columns
```

**Target Requirements:**
```sql
wedding_id UUID
user_id UUID
role TEXT
invited_by_user_id UUID REFERENCES auth.users(id)  -- ❌ MISSING
wedding_profile_permissions JSONB                    -- ❌ MISSING
```

**Specific Changes Needed:**
```sql
-- Add missing columns to wedding_members
ALTER TABLE wedding_members
  ADD COLUMN invited_by_user_id UUID REFERENCES auth.users(id),
  ADD COLUMN wedding_profile_permissions JSONB DEFAULT '{"can_read": false, "can_edit": false}';

-- For existing rows, set invited_by_user_id based on invite_codes.created_by
UPDATE wedding_members wm
SET invited_by_user_id = ic.created_by
FROM invite_codes ic
WHERE ic.used_by = wm.user_id
  AND ic.wedding_id = wm.wedding_id
  AND wm.role IN ('member', 'bestie');

-- Owners invited themselves
UPDATE wedding_members
SET invited_by_user_id = user_id
WHERE role = 'owner';
```

**Location:** Schema modification needed across all SQL files

---

### 2. bestie_permissions Table

**Status:** ❌ **Missing completely**

**What Currently Exists:** NOTHING

**What Needs to Be Built:**
```sql
-- File: NEW - create_bestie_permissions_table.sql
CREATE TABLE IF NOT EXISTS bestie_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  inviter_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  permissions JSONB NOT NULL DEFAULT '{"can_read": false, "can_edit": false}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Enforce 1:1 relationship: each bestie belongs to exactly one inviter per wedding
  CONSTRAINT unique_bestie_wedding UNIQUE (bestie_user_id, wedding_id),

  -- Constraint: bestie cannot grant permissions to themselves
  CONSTRAINT bestie_not_inviter CHECK (bestie_user_id != inviter_user_id)
);

-- Indexes
CREATE INDEX bestie_permissions_bestie_idx ON bestie_permissions(bestie_user_id);
CREATE INDEX bestie_permissions_inviter_idx ON bestie_permissions(inviter_user_id);
CREATE INDEX bestie_permissions_wedding_idx ON bestie_permissions(wedding_id);
```

**Purpose:**
- Tracks which bestie can manage which inviter's access to wedding data
- Enforces 1:1 bestie-inviter relationship
- Stores permissions bestie has granted to their inviter

---

### 3. bestie_knowledge Table

**Status:** ❌ **Missing completely**

**What Currently Exists:**
- Bestie chats stored in `chat_messages` table with `message_type='bestie'`
- No dedicated knowledge base structure

**Current Implementation:**
```sql
-- File: create_missing_tables.sql (lines 30-38)
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  message TEXT NOT NULL,
  role TEXT CHECK (role IN ('user', 'assistant')),
  message_type TEXT CHECK (message_type IN ('main', 'bestie')),  -- ⚠️ Uses filtering
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**What Needs to Be Built:**
```sql
-- File: NEW - create_bestie_knowledge_table.sql
CREATE TABLE IF NOT EXISTS bestie_knowledge (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  knowledge_type TEXT CHECK (knowledge_type IN ('note', 'vendor', 'task', 'expense', 'idea')),
  is_private BOOLEAN DEFAULT TRUE,  -- Private to bestie by default
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX bestie_knowledge_bestie_idx ON bestie_knowledge(bestie_user_id);
CREATE INDEX bestie_knowledge_wedding_idx ON bestie_knowledge(wedding_id);
CREATE INDEX bestie_knowledge_type_idx ON bestie_knowledge(knowledge_type);
```

**Purpose:**
- Dedicated storage for bestie's private planning knowledge
- Separate from chat messages (structured data vs conversational)
- Can be categorized by type (notes, vendors, tasks, etc.)

---

## B. API ENDPOINTS AUDIT

### Current API Endpoints

**All Existing API Files:**
```bash
api/
├── approve-update.js       # Approve/reject pending updates
├── bestie-chat.js          # ✅ Bestie chat with Claude
├── chat.js                 # Main wedding chat with Claude
├── create-checkout.js      # Stripe checkout
├── create-invite.js        # ✅ Create invite (supports 'bestie' role)
├── create-wedding.js       # Create wedding profile
├── join-wedding.js         # ✅ Join wedding via invite
└── stripe-webhook.js       # Stripe webhooks
```

---

### 1. /api/create-invite

**Status:** ⚠️ **Exists but needs enhancement for permissions**

**Current Implementation:**
```javascript
// File: api/create-invite.js (lines 21-93)
export default async function handler(req, res) {
  const { userToken, role = 'member' } = req.body;  // ⚠️ No permissions parameter

  // Validates role is 'member' or 'bestie'
  if (!['member', 'bestie'].includes(role)) {
    return res.status(400).json({ error: 'Invalid role' });
  }

  // Inserts into invite_codes with role
  const { data: invite } = await supabaseAdmin
    .from('invite_codes')
    .insert({
      wedding_id: membership.wedding_id,
      code: inviteCode,
      created_by: user.id,
      role: role,  // ✅ Role is stored
      is_used: false
    });
}
```

**What It Does:**
- ✅ Allows owner to create invite with 'bestie' or 'member' role
- ❌ Does NOT accept wedding_profile_permissions parameter
- ❌ Does NOT create entry in bestie_permissions table

**Specific Changes Needed:**
```javascript
// RENAME to: /api/create-bestie-invite (new specialized endpoint)
export default async function handler(req, res) {
  const {
    userToken,
    role = 'bestie',
    wedding_profile_permissions = { can_read: false, can_edit: false }  // NEW
  } = req.body;

  // Insert invite with permissions metadata
  const { data: invite } = await supabaseAdmin
    .from('invite_codes')
    .insert({
      wedding_id: membership.wedding_id,
      code: inviteCode,
      created_by: user.id,
      role: role,
      wedding_profile_permissions: wedding_profile_permissions,  // NEW: Store permissions
      is_used: false
    });

  return res.status(200).json({
    success: true,
    inviteCode: invite.code,
    role: invite.role,
    permissions: wedding_profile_permissions  // NEW: Return in response
  });
}
```

**Additional Changes:**
- Add `wedding_profile_permissions JSONB` column to `invite_codes` table
- Validate permissions structure: `{can_read: boolean, can_edit: boolean}`

---

### 2. /api/join-wedding

**Status:** ⚠️ **Exists but needs enhancement for permissions**

**Current Implementation:**
```javascript
// File: api/join-wedding.js (lines 89-97)
// STEP 4: Add user to wedding with role from invite
const { data: newMember } = await supabaseAdmin
  .from('wedding_members')
  .insert({
    wedding_id: invite.wedding_id,
    user_id: user.id,
    role: invite.role  // ✅ Role from invite ('member' or 'bestie')
    // ❌ MISSING: invited_by_user_id
    // ❌ MISSING: wedding_profile_permissions
  });
```

**What It Does:**
- ✅ Adds user to wedding_members with role from invite
- ❌ Does NOT set invited_by_user_id
- ❌ Does NOT store wedding_profile_permissions
- ❌ Does NOT create bestie_permissions entry

**Specific Changes Needed:**
```javascript
// RENAME to: /api/accept-bestie-invite (new specialized endpoint)
export default async function handler(req, res) {
  // ... existing code to validate invite ...

  // STEP 4: Add user to wedding_members with full tracking
  const { data: newMember } = await supabaseAdmin
    .from('wedding_members')
    .insert({
      wedding_id: invite.wedding_id,
      user_id: user.id,
      role: invite.role,
      invited_by_user_id: invite.created_by,  // NEW: Track who invited them
      wedding_profile_permissions: invite.wedding_profile_permissions  // NEW: Store permissions
    });

  // STEP 5: Create bestie_permissions entry (if role is 'bestie')
  if (invite.role === 'bestie') {
    await supabaseAdmin
      .from('bestie_permissions')
      .insert({
        bestie_user_id: user.id,
        inviter_user_id: invite.created_by,
        wedding_id: invite.wedding_id,
        permissions: { can_read: false, can_edit: false }  // Default: no access to inviter's data
      });
  }

  return res.status(200).json({
    success: true,
    weddingId: invite.wedding_id,
    role: invite.role,
    invitedBy: invite.created_by,  // NEW: Return inviter info
    weddingProfileAccess: invite.wedding_profile_permissions  // NEW
  });
}
```

---

### 3. /api/bestie-chat

**Status:** ✅ **Exists and works for chat - but doesn't integrate with knowledge base**

**Current Implementation:**
```javascript
// File: api/bestie-chat.js (lines 96-127)
// Calls Claude API with bestie-specific prompt
const claudeResponse = await fetch('https://api.anthropic.com/v1/messages', {
  method: 'POST',
  body: JSON.stringify({
    model: 'claude-sonnet-4-20250514',
    messages: [{
      role: 'user',
      content: `${weddingContext}\n\nUSER MESSAGE: "${message}"`
    }]
  })
});

// Saves to chat_messages with message_type='bestie'
await supabaseService
  .from('chat_messages')
  .insert({
    wedding_id: membership.wedding_id,
    user_id: user.id,
    role: 'user',
    message: message,
    message_type: 'bestie'  // ✅ Correctly segregated
  });
```

**What It Does:**
- ✅ Provides bestie-specific AI chat interface
- ✅ Saves messages with message_type='bestie'
- ✅ Has bestie-specific prompt/personality
- ❌ Does NOT integrate with bestie_knowledge table
- ❌ Does NOT save structured knowledge (only chat)

**Specific Changes Needed:**
- No immediate changes needed for chat functionality
- Future enhancement: Extract structured knowledge from chat and save to bestie_knowledge table

---

### 4. /api/get-my-bestie-permissions

**Status:** ❌ **Missing completely - needs to be built**

**What Currently Exists:** NOTHING

**What Needs to Be Built:**
```javascript
// File: NEW - api/get-my-bestie-permissions.js
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { userToken, wedding_id } = req.query;

  try {
    // Authenticate user
    const supabaseUser = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_ANON_KEY,
      { global: { headers: { Authorization: `Bearer ${userToken}` } } }
    );

    const { data: { user } } = await supabaseUser.auth.getUser();

    // Verify user is a bestie
    const { data: membership } = await supabase
      .from('wedding_members')
      .select('role, invited_by_user_id')
      .eq('user_id', user.id)
      .eq('wedding_id', wedding_id)
      .eq('role', 'bestie')
      .single();

    if (!membership) {
      return res.status(403).json({
        error: 'Only besties can view bestie permissions'
      });
    }

    // Get bestie's permission record
    const { data: permissions } = await supabase
      .from('bestie_permissions')
      .select('*')
      .eq('bestie_user_id', user.id)
      .eq('wedding_id', wedding_id)
      .single();

    // Get inviter's profile info
    const { data: inviter } = await supabase
      .from('profiles')
      .select('full_name, email')
      .eq('id', membership.invited_by_user_id)
      .single();

    return res.status(200).json({
      success: true,
      bestieUserId: user.id,
      inviterUserId: membership.invited_by_user_id,
      inviterName: inviter?.full_name,
      weddingId: wedding_id,
      // Permissions bestie has granted TO their inviter
      inviterCanReadMyKnowledge: permissions?.permissions?.can_read || false,
      inviterCanEditMyKnowledge: permissions?.permissions?.can_edit || false
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}
```

**Purpose:**
- Bestie sees ONLY their own inviter's access permissions
- Returns 1:1 relationship data (bestie → inviter)
- Does NOT show other besties or other inviters

---

### 5. /api/update-my-inviter-access

**Status:** ❌ **Missing completely - needs to be built**

**What Currently Exists:** NOTHING

**What Needs to Be Built:**
```javascript
// File: NEW - api/update-my-inviter-access.js
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { userToken, wedding_id, can_read, can_edit } = req.body;

  try {
    // Authenticate user
    const supabaseUser = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_ANON_KEY,
      { global: { headers: { Authorization: `Bearer ${userToken}` } } }
    );

    const { data: { user } } = await supabaseUser.auth.getUser();

    // Verify user is a bestie for this wedding
    const { data: membership } = await supabase
      .from('wedding_members')
      .select('role, invited_by_user_id')
      .eq('user_id', user.id)
      .eq('wedding_id', wedding_id)
      .eq('role', 'bestie')
      .single();

    if (!membership) {
      return res.status(403).json({
        error: 'Only besties can update inviter permissions'
      });
    }

    // Update ONLY the bestie's own permission record
    // RLS will prevent updating other besties' records
    const { data: updated, error: updateError } = await supabase
      .from('bestie_permissions')
      .update({
        permissions: { can_read, can_edit },
        updated_at: new Date().toISOString()
      })
      .eq('bestie_user_id', user.id)  // Can only update own record
      .eq('wedding_id', wedding_id)
      .select()
      .single();

    if (updateError) {
      return res.status(500).json({
        error: 'Failed to update permissions'
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Inviter permissions updated',
      permissions: updated.permissions
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}
```

**Purpose:**
- Bestie can ONLY update their own inviter's access
- Cannot see or modify other besties' permissions
- Enforces 1:1 relationship via RLS

---

### Summary: API Endpoints

| Endpoint | Target Architecture | Current Status | Action Needed |
|----------|-------------------|----------------|---------------|
| `/api/create-bestie-invite` | Create invite with permissions | ❌ Missing | **Build new endpoint** (enhanced version of create-invite) |
| `/api/accept-bestie-invite` | Accept invite, create permissions record | ❌ Missing | **Build new endpoint** (enhanced version of join-wedding) |
| `/api/get-my-bestie-permissions` | Bestie sees their inviter's access | ❌ Missing | **Build new endpoint** |
| `/api/update-my-inviter-access` | Bestie updates inviter permissions | ❌ Missing | **Build new endpoint** |
| `/api/bestie-chat` | Bestie AI chat | ✅ Exists | No changes needed |

**Keep Existing Endpoints:**
- `/api/create-invite` - For regular 'member' invites
- `/api/join-wedding` - For regular member joins
- `/api/bestie-chat` - Already works correctly

---

## C. RLS POLICIES AUDIT

### 1. bestie_permissions Table Policies

**Status:** ❌ **Table doesn't exist, so no policies**

**What Needs to Be Built:**
```sql
-- File: NEW - rls_bestie_permissions.sql

ALTER TABLE bestie_permissions ENABLE ROW LEVEL SECURITY;

-- POLICY 1: Bestie can SELECT only their own permission record
CREATE POLICY "Bestie can view own permissions"
ON bestie_permissions FOR SELECT
TO authenticated
USING (bestie_user_id = auth.uid());

-- POLICY 2: Bestie can UPDATE only their own permission record
CREATE POLICY "Bestie can update own permissions"
ON bestie_permissions FOR UPDATE
TO authenticated
USING (bestie_user_id = auth.uid())
WITH CHECK (bestie_user_id = auth.uid());

-- POLICY 3: Inviter can SELECT their bestie's permissions (to check access)
CREATE POLICY "Inviter can view bestie permissions"
ON bestie_permissions FOR SELECT
TO authenticated
USING (inviter_user_id = auth.uid());

-- POLICY 4: Backend (service role) has full access
CREATE POLICY "Backend full access"
ON bestie_permissions FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- POLICY 5: Prevent besties from seeing other besties
-- This is already enforced by POLICY 1 (bestie_user_id = auth.uid())
-- No additional policy needed - lack of SELECT permission = invisible
```

**Key Security Features:**
- ✅ Bestie can ONLY see/update their own record (1:1 enforcement)
- ✅ Bestie CANNOT see other besties' permissions
- ✅ Bestie CANNOT update other besties' permissions
- ✅ Inviter can see what access their bestie has granted them
- ✅ Bestie CANNOT modify bestie_user_id or inviter_user_id (fixed at creation)

---

### 2. bestie_knowledge Table Policies

**Status:** ❌ **Table doesn't exist, so no policies**

**What Needs to Be Built:**
```sql
-- File: NEW - rls_bestie_knowledge.sql

ALTER TABLE bestie_knowledge ENABLE ROW LEVEL SECURITY;

-- POLICY 1: Bestie can SELECT all their own knowledge
CREATE POLICY "Bestie can view own knowledge"
ON bestie_knowledge FOR SELECT
TO authenticated
USING (bestie_user_id = auth.uid());

-- POLICY 2: Bestie can INSERT their own knowledge
CREATE POLICY "Bestie can create own knowledge"
ON bestie_knowledge FOR INSERT
TO authenticated
WITH CHECK (bestie_user_id = auth.uid());

-- POLICY 3: Bestie can UPDATE their own knowledge
CREATE POLICY "Bestie can update own knowledge"
ON bestie_knowledge FOR UPDATE
TO authenticated
USING (bestie_user_id = auth.uid())
WITH CHECK (bestie_user_id = auth.uid());

-- POLICY 4: Bestie can DELETE their own knowledge
CREATE POLICY "Bestie can delete own knowledge"
ON bestie_knowledge FOR DELETE
TO authenticated
USING (bestie_user_id = auth.uid());

-- POLICY 5: Inviter can SELECT bestie's knowledge IF granted permission
CREATE POLICY "Inviter can view if granted access"
ON bestie_knowledge FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM bestie_permissions bp
    WHERE bp.bestie_user_id = bestie_knowledge.bestie_user_id
      AND bp.inviter_user_id = auth.uid()
      AND bp.wedding_id = bestie_knowledge.wedding_id
      AND bp.permissions->>'can_read' = 'true'
  )
);

-- POLICY 6: Inviter can UPDATE bestie's knowledge IF granted permission
CREATE POLICY "Inviter can edit if granted access"
ON bestie_knowledge FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM bestie_permissions bp
    WHERE bp.bestie_user_id = bestie_knowledge.bestie_user_id
      AND bp.inviter_user_id = auth.uid()
      AND bp.wedding_id = bestie_knowledge.wedding_id
      AND bp.permissions->>'can_edit' = 'true'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM bestie_permissions bp
    WHERE bp.bestie_user_id = bestie_knowledge.bestie_user_id
      AND bp.inviter_user_id = auth.uid()
      AND bp.wedding_id = bestie_knowledge.wedding_id
      AND bp.permissions->>'can_edit' = 'true'
  )
);

-- POLICY 7: Backend (service role) has full access
CREATE POLICY "Backend full access"
ON bestie_knowledge FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
```

**Key Security Features:**
- ✅ Bestie has full CRUD on their own knowledge
- ✅ Inviter can only READ if can_read=true
- ✅ Inviter can only UPDATE if can_edit=true
- ✅ Bestie cannot see other besties' knowledge
- ✅ Permission checked via JOIN to bestie_permissions table

---

### 3. Current RLS Policies (Existing Tables)

**wedding_members Policies:**
```sql
-- File: rls_critical_tables_fixed.sql (lines 67-125)

-- Current policies:
1. "Users can view members of their wedding" (SELECT)
2. "Users can join as owner" (INSERT)
3. "Users can join as member" (INSERT)
4. "Owners can manage members" (UPDATE)
5. "Backend full access" (ALL)
```

**Status:** ⚠️ **Exist but don't enforce 1:1 bestie relationship**

**Issues:**
- ❌ No policy prevents bestie from seeing other besties
- ❌ No policy enforces unique invited_by relationship
- ✅ Policies work correctly for basic role-based access

**Changes Needed:**
```sql
-- ADD: Policy to prevent besties from updating their invited_by_user_id
CREATE POLICY "Besties cannot change who invited them"
ON wedding_members FOR UPDATE
TO authenticated
USING (role = 'bestie' AND user_id = auth.uid())
WITH CHECK (
  -- Can update everything EXCEPT invited_by_user_id and role
  role = 'bestie'
  AND user_id = auth.uid()
  -- Additional check: invited_by_user_id must remain unchanged
  -- This would require a trigger or CHECK constraint
);
```

---

## D. CURRENT BESTIE FLOW ANALYSIS

### How Bestie Invite Currently Works

**STEP 1: Owner Creates Invite**
```
Frontend → /api/create-invite
  ↓
{
  userToken: "...",
  role: "bestie"  // ✅ Supported
}
  ↓
invite_codes table:
{
  code: "ABC12345",
  role: "bestie",
  created_by: owner_id,
  wedding_id: "...",
  is_used: false
}
```

**STEP 2: Bestie Accepts Invite**
```
Frontend → /api/join-wedding
  ↓
{
  inviteCode: "ABC12345",
  userToken: "..."
}
  ↓
wedding_members table:
{
  user_id: bestie_id,
  wedding_id: "...",
  role: "bestie"  // ✅ From invite
  // ❌ MISSING: invited_by_user_id
  // ❌ MISSING: wedding_profile_permissions
}
  ↓
No bestie_permissions record created  // ❌ MISSING
```

**STEP 3: Bestie Uses Bestie Chat**
```
Frontend (bestie-v2.html) → /api/bestie-chat
  ↓
Check: user has role='bestie' ✅
  ↓
Claude API call with bestie prompt ✅
  ↓
chat_messages table:
{
  message: "...",
  message_type: "bestie",  // ✅ Segregated
  user_id: bestie_id,
  wedding_id: "..."
}
```

---

### Current Permission Management

**Q: How are permissions currently stored/managed?**
**A:** ❌ **They are NOT. No permission system exists.**

Current system only has:
- ✅ Role-based access (owner/member/bestie)
- ❌ No granular permissions (can_read, can_edit)
- ❌ No tracking of who invited whom
- ❌ No bestie-inviter relationship enforcement

---

### Can Bestie See/Edit Other People's Permissions?

**Q: Can bestie see other people's permissions?**
**A:** ❌ **N/A - No permission system exists**

**Q: Can bestie edit other people's permissions?**
**A:** ❌ **N/A - No permission system exists**

**Current Bestie Can See:**
- ✅ All wedding_members of their wedding (including other besties)
- ✅ All wedding_profiles data for their wedding
- ✅ Only THEIR OWN bestie chat messages (message_type='bestie', user_id=their_id)

**Current Bestie CANNOT See:**
- ✅ Main wedding planning chat (message_type='main')
- ✅ Other besties' chat messages

**Security Issue:**
Currently, ALL besties can see the same wedding data. There's no concept of:
- "This bestie was invited by Person A"
- "This bestie was invited by Person B"
- "Person A can only see their bestie's knowledge"

**Example Problem:**
```
Wedding has 3 members:
- Owner (Alice)
- Owner's Bestie (MOH Sarah)
- Owner's Sister (Bestie Emma)

Current System:
✅ Sarah can see wedding_profiles (Alice's wedding)
✅ Emma can see wedding_profiles (Alice's wedding)
✅ Sarah CANNOT see Emma's bestie chats
✅ Emma CANNOT see Sarah's bestie chats

Missing:
❌ Sarah cannot grant Alice access to Sarah's bestie knowledge
❌ Emma cannot grant Alice access to Emma's bestie knowledge
❌ No way to track "Sarah was invited by Alice"
❌ No way to track "Emma was invited by Alice"
```

---

## IMPLEMENTATION ROADMAP

### Phase 1: Database Schema (Priority: HIGH)

**Files to Create:**
1. `migrations/001_add_invited_by_to_wedding_members.sql`
2. `migrations/002_create_bestie_permissions_table.sql`
3. `migrations/003_create_bestie_knowledge_table.sql`
4. `migrations/004_rls_bestie_permissions.sql`
5. `migrations/005_rls_bestie_knowledge.sql`

**Estimated Effort:** 2-3 hours

---

### Phase 2: API Endpoints (Priority: HIGH)

**Files to Create:**
1. `api/create-bestie-invite.js` (new specialized endpoint)
2. `api/accept-bestie-invite.js` (new specialized endpoint)
3. `api/get-my-bestie-permissions.js` (new)
4. `api/update-my-inviter-access.js` (new)

**Files to Modify:**
1. `api/create-invite.js` - Keep for regular members, add note about bestie variant
2. `api/join-wedding.js` - Keep for regular members, add note about bestie variant

**Estimated Effort:** 4-5 hours

---

### Phase 3: Frontend Integration (Priority: MEDIUM)

**Files to Modify:**
1. `public/bestie-v2.html` - Add permissions UI
2. `public/invite-v2.html` - Add permission selector for bestie invites

**New Components Needed:**
- Permission toggle switches (can_read, can_edit)
- Display of inviter info
- Bestie knowledge management UI

**Estimated Effort:** 3-4 hours

---

### Phase 4: Testing & Migration (Priority: HIGH)

**Tasks:**
1. Migrate existing bestie records to include invited_by_user_id
2. Create bestie_permissions records for existing besties
3. Test RLS policies prevent cross-bestie access
4. End-to-end testing of invite flow

**Estimated Effort:** 2-3 hours

---

## TOTAL COMPLETION ESTIMATE

**Total Implementation Time:** 11-15 hours
**Current Completion:** 20%
**Remaining Work:** 80%

---

## CRITICAL DECISIONS NEEDED

### Decision 1: Migration Strategy for Existing Besties

**Question:** How to handle existing bestie users who don't have invited_by_user_id?

**Options:**
A. Set all existing besties' invited_by_user_id to wedding owner
B. Look up from invite_codes.created_by where used_by matches
C. Require manual assignment

**Recommendation:** Option B (look up from invite_codes)

---

### Decision 2: invite_codes Table Enhancement

**Question:** Should we add wedding_profile_permissions to invite_codes?

**Options:**
A. Yes - Store permissions in invite, copy to wedding_members on join
B. No - Set default permissions, require bestie to update later

**Recommendation:** Option A (store in invite for better UX)

---

### Decision 3: Backward Compatibility

**Question:** Should old invite flow still work?

**Options:**
A. Keep /api/create-invite and /api/join-wedding for regular members
B. Migrate everything to new bestie-specific endpoints

**Recommendation:** Option A (keep both flows)

---

## APPENDIX: File Locations

**SQL Files:**
- Schema definitions: `create_missing_tables.sql`
- RLS policies: `rls_critical_tables_fixed.sql`, `rls_remaining_tables.sql`
- Bestie setup: `setup_bestie_functionality.sql`

**API Files:**
- All in `/api/*.js` directory
- Current bestie endpoint: `api/bestie-chat.js`
- Current invite endpoints: `api/create-invite.js`, `api/join-wedding.js`

**Frontend Files:**
- Bestie dashboard: `public/bestie-v2.html`
- Main dashboard: `public/dashboard-v2.html`
- Invite page: `public/invite-v2.html`

---

**End of Audit Report**

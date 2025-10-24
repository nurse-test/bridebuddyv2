# 🔍 SCHEMA & RLS ANALYSIS vs DESIGN REQUIREMENTS

**Analysis Date:** October 24, 2025
**Database:** Bride Buddy V2 - Supabase PostgreSQL

---

## EXECUTIVE SUMMARY

Your current implementation uses a **simplified role-based access model** instead of the **granular permission-based system** described in your requirements.

**Overall Assessment:**
- ✅ 2 requirements fully implemented
- ⚠️ 2 requirements partially implemented
- ❌ 1 requirement completely missing

---

## 📊 REQUIREMENT-BY-REQUIREMENT ANALYSIS

---

## 1️⃣ PRIVATE CHAT SESSIONS

### ✅ **STATUS: CORRECTLY IMPLEMENTED**

### **Current Schema**

```sql
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY,
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),  -- WHO owns this chat
  message TEXT NOT NULL,
  role TEXT CHECK (role IN ('user', 'assistant')),
  message_type TEXT CHECK (message_type IN ('main', 'bestie')),  -- Chat category
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Key Columns:**
- ✅ `user_id` - Tracks who owns each message
- ✅ `wedding_id` - Links to wedding context
- ✅ `message_type` - Separates main vs bestie chats

### **Current RLS Policy**

```sql
-- Policy: "Users can view own chat messages"
-- Location: rls_remaining_tables.sql
CREATE POLICY "Users can view own chat messages"
ON chat_messages FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()  -- ✅ BLOCKS other users' messages
  AND wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

-- Backend can insert messages (AI responses)
CREATE POLICY "Backend can insert messages"
ON chat_messages FOR INSERT
TO service_role
WITH CHECK (true);
```

### **Verification Test**

```sql
-- Test 1: User A cannot see User B's chat messages
-- Run as User A:
SELECT * FROM chat_messages WHERE user_id != auth.uid();
-- Expected: 0 rows (blocked by RLS)

-- Test 2: User can only see their own messages
SELECT * FROM chat_messages;
-- Expected: Only messages where user_id = your ID
```

### ✅ **VERDICT: FULLY COMPLIANT**

**What's Working:**
- ✅ Each user has completely private chat sessions
- ✅ RLS enforces `user_id = auth.uid()` check
- ✅ No user can see other members' messages
- ✅ Backend service role can save AI responses

**Gap:** None - this requirement is fully implemented.

---

## 2️⃣ SHARED WEDDING KNOWLEDGE BASE (Permission-based)

### ⚠️ **STATUS: PARTIALLY IMPLEMENTED - MISSING PERMISSION SYSTEM**

### **Current Schema**

```sql
-- wedding_profiles table (actual fields used in code)
CREATE TABLE wedding_profiles (
  id UUID PRIMARY KEY,
  owner_id UUID NOT NULL,  -- Only 1 owner, no partner distinction

  -- Wedding data (shared knowledge base)
  wedding_name TEXT,
  partner1_name TEXT,
  partner2_name TEXT,
  wedding_date DATE,
  wedding_time TIME,
  ceremony_location TEXT,
  reception_location TEXT,
  venue_name TEXT,
  venue_cost NUMERIC,
  expected_guest_count INTEGER,
  total_budget NUMERIC,
  wedding_style TEXT,
  color_scheme_primary TEXT,

  -- Vendor data
  photographer_name TEXT,
  photographer_cost NUMERIC,
  caterer_name TEXT,
  caterer_cost NUMERIC,
  florist_name TEXT,
  florist_cost NUMERIC,
  dj_band_name TEXT,
  dj_band_cost NUMERIC,
  baker_name TEXT,
  cake_flavors TEXT,

  -- Subscription
  trial_start_date TIMESTAMPTZ,
  trial_end_date TIMESTAMPTZ,
  plan_type TEXT,
  subscription_status TEXT,
  bestie_addon_enabled BOOLEAN,
  is_vip BOOLEAN,
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT
);

-- wedding_members table (access control)
CREATE TABLE wedding_members (
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  role TEXT CHECK (role IN ('owner', 'member', 'bestie')),
  created_at TIMESTAMPTZ DEFAULT NOW(),

  PRIMARY KEY (wedding_id, user_id),
  UNIQUE (wedding_id, user_id)
);
```

### ❌ **MISSING FIELDS**

```sql
-- Fields that DON'T exist but SHOULD for your requirements:
ALTER TABLE wedding_members ADD COLUMN permissions JSONB;
-- Example: {"read": true, "edit": false}

ALTER TABLE wedding_members ADD COLUMN invited_by UUID REFERENCES auth.users(id);
-- Tracks if invited by owner vs partner

ALTER TABLE wedding_members ADD COLUMN can_read BOOLEAN DEFAULT true;
ALTER TABLE wedding_members ADD COLUMN can_edit BOOLEAN DEFAULT false;
-- Granular permission flags
```

### **Current RLS Policies**

```sql
-- Policy 1: Users can view weddings they're members of
CREATE POLICY "Users can view their weddings"
ON wedding_profiles FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);
-- ✅ Works: All members can READ
-- ❌ Issue: No granular read permissions

-- Policy 2: Only owner can UPDATE
CREATE POLICY "Owners can update their wedding"
ON wedding_profiles FOR UPDATE
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());
-- ❌ Issue: Only owner can edit, not co-planners with edit permissions
-- ❌ Issue: No partner role distinction
```

### ⚠️ **WHAT'S MISSING**

| Requirement | Current State | Missing |
|-------------|---------------|---------|
| Owner + Partner full access | ❌ Only owner_id field exists | Partner role/distinction |
| Co-planner read/edit based on permissions | ❌ All members have read, none have edit | Permissions field in wedding_members |
| Invited_by tracking | ❌ No field | `invited_by` column |
| Granular permissions | ❌ Simple role-based | Permission flags or JSONB field |

### **What Currently Happens**

```
Current Access Model:
┌─────────────┬──────────┬──────────┐
│ Role        │ Read     │ Edit     │
├─────────────┼──────────┼──────────┤
│ owner       │ ✅ Yes   │ ✅ Yes   │
│ member      │ ✅ Yes   │ ❌ No    │
│ bestie      │ ✅ Yes   │ ❌ No    │
└─────────────┴──────────┴──────────┘

Your Required Access Model:
┌─────────────┬──────────┬──────────┬─────────────────┐
│ Role        │ Read     │ Edit     │ Set By          │
├─────────────┼──────────┼──────────┼─────────────────┤
│ owner       │ ✅ Yes   │ ✅ Yes   │ System          │
│ partner     │ ✅ Yes   │ ✅ Yes   │ System          │
│ co-planner  │ ?        │ ?        │ Owner/Partner   │
│ bestie      │ ?        │ ?        │ Owner/Partner   │
└─────────────┴──────────┴──────────┴─────────────────┘
```

### ⚠️ **VERDICT: NEEDS ENHANCEMENT**

**What's Working:**
- ✅ Shared wedding data table exists
- ✅ All members can read wedding data
- ✅ Owner has full edit access

**Critical Gaps:**
- ❌ No permission system (all members have same read-only access)
- ❌ No partner role (only owner can edit)
- ❌ No invited_by tracking
- ❌ No granular read/edit permissions per user
- ❌ RLS policies don't check permission levels

---

## 3️⃣ BESTIE-SPECIFIC KNOWLEDGE BASE (Ultra private)

### ❌ **STATUS: NOT IMPLEMENTED - USES MESSAGE FILTERING INSTEAD**

### **Current Implementation**

```sql
-- Uses same chat_messages table with message_type filter
CREATE TABLE chat_messages (
  ...
  message_type TEXT CHECK (message_type IN ('main', 'bestie')),  -- Filter only
  ...
);
```

### **Current RLS Policy**

```sql
-- Same policy as Requirement 1 - filters by user_id
CREATE POLICY "Users can view own chat messages"
ON chat_messages FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  AND wedding_id IN (...)
);
```

### **How It Currently Works**

```
Current: All chat messages in ONE table
┌─────────────┬──────────────┬───────┬──────────┐
│ user_id     │ message_type │ Data  │ Isolated?│
├─────────────┼──────────────┼───────┼──────────┤
│ Bestie A    │ bestie       │ "..." │ ✅ Yes   │
│ Owner       │ main         │ "..." │ ✅ Yes   │
│ Co-planner  │ main         │ "..." │ ✅ Yes   │
└─────────────┴──────────────┴───────┴──────────┘

Each user only sees their OWN messages (filtered by user_id)
Bestie messages are NOT in a separate database
```

### ❌ **MISSING: Separate Bestie Knowledge Table**

```sql
-- What your requirement describes:
CREATE TABLE bestie_knowledge (
  id UUID PRIMARY KEY,
  wedding_id UUID REFERENCES wedding_profiles(id),
  bestie_user_id UUID REFERENCES auth.users(id),  -- Only THIS bestie

  -- Bestie-specific wedding data
  bachelorette_plans JSONB,
  bridal_shower_details JSONB,
  bridesmaid_expenses JSONB,
  surprise_plans JSONB,
  private_notes TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE (wedding_id, bestie_user_id)
);

-- RLS: ONLY the bestie can access
CREATE POLICY "Only bestie can access their knowledge"
ON bestie_knowledge FOR ALL
TO authenticated
USING (bestie_user_id = auth.uid())
WITH CHECK (bestie_user_id = auth.uid());
```

### **Verification: Can Owner/Partner See Bestie Data?**

```sql
-- Current implementation:
-- Run as Owner:
SELECT * FROM chat_messages WHERE message_type = 'bestie';
-- Result: 0 rows (✅ blocked by user_id check)

-- BUT: No separate bestie knowledge base exists
-- Bestie data is just private chat messages, not structured data
```

### ❌ **VERDICT: REQUIREMENT NOT MET**

**What Exists:**
- ✅ Bestie chat messages are private (via user_id isolation)
- ✅ Owner/partner cannot see bestie's messages

**Critical Gaps:**
- ❌ No separate `bestie_knowledge` or `bestie_data` table
- ❌ No structured bestie-specific fields (bachelorette plans, bridal shower, etc.)
- ❌ Bestie data is just chat messages, not a knowledge base
- ❌ Not a true "separate database" - uses same table with filtering

**What You Described vs What Exists:**

| Requirement | Exists? |
|-------------|---------|
| Separate bestie database | ❌ Uses chat_messages with filter |
| Structured bestie fields | ❌ Only freeform chat |
| Ultra-private (only bestie access) | ✅ Via user_id RLS |
| Owner/partner blocked | ✅ Via user_id RLS |

---

## 4️⃣ INVITE & PERMISSION SYSTEM

### ⚠️ **STATUS: BASIC ROLE-BASED INVITES, NO CUSTOM PERMISSIONS**

### **Current Schema**

```sql
CREATE TABLE invite_codes (
  id UUID PRIMARY KEY,
  wedding_id UUID REFERENCES wedding_profiles(id),
  code TEXT UNIQUE,
  created_by UUID REFERENCES auth.users(id),

  -- Role assignment (added by bestie setup)
  role TEXT CHECK (role IN ('member', 'bestie')),  -- ✅ Basic role

  is_used BOOLEAN DEFAULT FALSE,
  used_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ,
  used_at TIMESTAMPTZ
);
```

### ❌ **MISSING FIELDS**

```sql
-- Fields that DON'T exist but SHOULD:
ALTER TABLE invite_codes ADD COLUMN created_by_role TEXT;
-- Tracks if owner or partner created invite

ALTER TABLE invite_codes ADD COLUMN permissions JSONB;
-- Example: {"read": true, "edit": false, "fields": ["venue", "budget"]}

ALTER TABLE invite_codes ADD COLUMN can_read BOOLEAN DEFAULT true;
ALTER TABLE invite_codes ADD COLUMN can_edit BOOLEAN DEFAULT false;
```

### **Current Invite Flow**

```javascript
// From api/create-invite.js and EDGE_FUNCTIONS_SETUP.md
// Edge Function (not yet deployed):
{
  "wedding_id": "...",
  "code": "ABC12345",
  "created_by": "owner_user_id",
  "role": "member"  // or "bestie"
}

// What's missing:
// - No custom permissions in invite
// - No differentiation between owner vs partner creating invite
// - When invite is used, new member gets role but no granular permissions
```

### **Current RLS Policies**

```sql
-- Policy 1: Members can view invites for their weddings
CREATE POLICY "Users can view wedding invites"
ON invite_codes FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

-- Policy 2: Members can create invites
CREATE POLICY "Members can create invites"
ON invite_codes FOR INSERT
TO authenticated
WITH CHECK (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);
-- ❌ Issue: No check for owner vs partner creating invite
-- ❌ Issue: No permission assignment during creation
```

### ⚠️ **VERDICT: BASIC FUNCTIONALITY ONLY**

**What's Working:**
- ✅ Invite codes can be created
- ✅ Role assignment works (member vs bestie)
- ✅ One-time use enforcement (is_used flag)
- ✅ Tracks who created and who used invite

**Critical Gaps:**
- ❌ No custom read/edit permissions in invites
- ❌ Can't differentiate owner-created vs partner-created invites
- ❌ No granular field-level permissions (e.g., "can edit venue but not budget")
- ❌ RLS doesn't enforce permission levels
- ❌ All members get same access (read-only)

---

## 5️⃣ NOTIFICATION/APPROVAL FLOW

### ✅ **STATUS: CORRECTLY IMPLEMENTED**

### **Current Schema**

```sql
CREATE TABLE pending_updates (
  id UUID PRIMARY KEY,
  wedding_id UUID REFERENCES wedding_profiles(id),
  user_id UUID REFERENCES auth.users(id),  -- Who requested the update

  field_name TEXT NOT NULL,      -- What field to update
  old_value TEXT,                -- Current value
  new_value TEXT,                -- Proposed value

  status TEXT CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

### **Current RLS Policies**

```sql
-- Policy 1: Users can view updates for their weddings
CREATE POLICY "Users can view wedding updates"
ON pending_updates FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

-- Policy 2: Owners can approve/reject
CREATE POLICY "Owners can approve/reject updates"
ON pending_updates FOR UPDATE
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
    AND role = 'owner'  -- ✅ Only owners
  )
);

-- Policy 3: Backend can create updates
CREATE POLICY "Backend can create updates"
ON pending_updates FOR INSERT
TO service_role
WITH CHECK (true);
```

### **Current Approval Flow**

```javascript
// From api/approve-update.js

// Step 1: Co-planner/Bestie submits update
// (Currently done by AI in backend, not directly by users)

// Step 2: Owner sees pending updates in notifications-v2.html

// Step 3: Owner approves/rejects via /api/approve-update
if (approve) {
  // Apply the update to wedding_profiles
  const updateData = {};
  updateData[update.field_name] = update.new_value;

  await supabase
    .from('wedding_profiles')
    .update(updateData)
    .eq('id', wedding_id);

  // Mark as approved
  await supabase
    .from('pending_updates')
    .update({ status: 'approved' })
    .eq('id', updateId);
} else {
  // Mark as rejected
  await supabase
    .from('pending_updates')
    .update({ status: 'rejected' })
    .eq('id', updateId);
}
```

### ✅ **VERDICT: FULLY COMPLIANT**

**What's Working:**
- ✅ Pending updates table exists
- ✅ Stores field name, old value, new value
- ✅ Status workflow (pending → approved/rejected)
- ✅ Only owners can approve/reject (enforced by RLS)
- ✅ Approved updates write to shared knowledge base
- ✅ All members can view pending updates

**Minor Gap:**
- ⚠️ Currently only AI creates pending updates (in chat.js)
- ⚠️ No direct UI for co-planners to propose updates manually
- ⚠️ Should check if user has edit permissions before applying update (but permission system doesn't exist yet)

---

## 📋 SUMMARY SCORECARD

| # | Requirement | Status | Score |
|---|-------------|--------|-------|
| 1 | Private Chat Sessions | ✅ Fully Implemented | 100% |
| 2 | Shared Wedding Knowledge (Permissions) | ⚠️ Partial - Missing permissions | 40% |
| 3 | Bestie-Specific Knowledge Base | ❌ Not Implemented | 20% |
| 4 | Invite & Permission System | ⚠️ Basic role-based only | 50% |
| 5 | Notification/Approval Flow | ✅ Fully Implemented | 95% |

**Overall Implementation:** **61%**

---

## 🚨 CRITICAL GAPS TO ADDRESS

### **HIGH PRIORITY**

1. **Add Permission System to wedding_members**
   ```sql
   ALTER TABLE wedding_members
   ADD COLUMN can_read BOOLEAN DEFAULT true,
   ADD COLUMN can_edit BOOLEAN DEFAULT false,
   ADD COLUMN invited_by UUID REFERENCES auth.users(id),
   ADD COLUMN permissions JSONB;  -- For field-level permissions
   ```

2. **Update RLS Policies for Permission Checks**
   ```sql
   -- Example: Check edit permissions before allowing updates
   CREATE POLICY "Members with edit permissions can update"
   ON wedding_profiles FOR UPDATE
   TO authenticated
   USING (
     owner_id = auth.uid()
     OR id IN (
       SELECT wedding_id FROM wedding_members
       WHERE user_id = auth.uid() AND can_edit = true
     )
   );
   ```

3. **Create Bestie Knowledge Table**
   ```sql
   CREATE TABLE bestie_knowledge (
     id UUID PRIMARY KEY,
     wedding_id UUID REFERENCES wedding_profiles(id),
     bestie_user_id UUID REFERENCES auth.users(id),
     data JSONB,  -- Structured bestie-specific data
     UNIQUE (wedding_id, bestie_user_id)
   );
   ```

### **MEDIUM PRIORITY**

4. **Add Partner Role/Distinction**
   - Either add `partner_id` to wedding_profiles
   - Or add `is_partner` boolean to wedding_members

5. **Enhance Invite System**
   ```sql
   ALTER TABLE invite_codes
   ADD COLUMN permissions JSONB,
   ADD COLUMN created_by_role TEXT;
   ```

6. **Update Edge Functions** (when deployed)
   - Pass permissions when creating invites
   - Apply permissions when user joins via invite

---

## 🎯 RECOMMENDED MIGRATION PATH

### **Phase 1: Add Permission Fields (1-2 hours)**
```sql
-- Add to wedding_members
ALTER TABLE wedding_members
ADD COLUMN can_read BOOLEAN DEFAULT true,
ADD COLUMN can_edit BOOLEAN DEFAULT false,
ADD COLUMN invited_by UUID REFERENCES auth.users(id);

-- Add to invite_codes
ALTER TABLE invite_codes
ADD COLUMN can_read BOOLEAN DEFAULT true,
ADD COLUMN can_edit BOOLEAN DEFAULT false;
```

### **Phase 2: Update RLS Policies (30 minutes)**
```sql
-- Modify wedding_profiles UPDATE policy
DROP POLICY "Owners can update their wedding" ON wedding_profiles;

CREATE POLICY "Users with edit access can update"
ON wedding_profiles FOR UPDATE
TO authenticated
USING (
  owner_id = auth.uid()
  OR id IN (
    SELECT wedding_id FROM wedding_members
    WHERE user_id = auth.uid() AND can_edit = true
  )
);
```

### **Phase 3: Create Bestie Knowledge Table (1 hour)**
```sql
-- See "Create Bestie Knowledge Table" section above
```

### **Phase 4: Update Edge Functions (1-2 hours)**
- Modify create-invite to accept permissions
- Modify join-wedding to apply permissions to new member

### **Phase 5: Update Frontend (2-3 hours)**
- Add permission checkboxes to invite creation UI
- Update API calls to pass permissions
- Add UI for co-planners to submit updates

---

## 📁 FILES TO CREATE

Save this analysis and create these new migration files:

1. `add_permission_system.sql` - Adds permission fields
2. `update_rls_for_permissions.sql` - Updates policies to check permissions
3. `create_bestie_knowledge.sql` - Creates bestie knowledge table
4. `add_partner_support.sql` - Adds partner role distinction

---

**End of Analysis**

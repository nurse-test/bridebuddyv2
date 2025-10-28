# Chat Extraction & Dashboard Widget Issues - Comprehensive Analysis

## Executive Summary

Investigation identified **4 critical column name mismatches** between database writes (chat extraction) and reads (dashboard widgets), plus **RLS policy gaps** that prevent proper data visibility. These issues cascade to cause silent failures in data extraction and empty dashboard displays.

---

## ISSUE 1: Critical Column Name Mismatch - Wedding Date

### Problem
**Wedding date reference is inconsistent across the application:**

- **Database Column:** `wedding_profiles.wedding_date` (DATE type) ← ACTUAL
- **Dashboard reads from:** `wedding.ceremony_date` ← WRONG
- **Chat writes to:** `weddingData.wedding_date` ← CORRECT

### Impact
Dashboard fails to display countdown because:
1. Chat extraction writes to `wedding_date` ✓
2. Dashboard queries `wedding_profiles` and gets all columns ✓
3. Dashboard code tries to access `wedding.ceremony_date` ✗ (undefined)
4. JavaScript throws silent error, countdown shows "--"

### Code References
**File: `/home/user/bridebuddyv2/public/dashboard-luxury.html` (Lines 337-345)**
```javascript
// WRONG - Column doesn't exist
if (wedding.ceremony_date) {
    const days = calculateDaysUntil(wedding.ceremony_date);
    document.getElementById('daysUntil').textContent = days > 0 ? days : '0';
    const dateStr = new Date(wedding.ceremony_date).toLocaleDateString('en-US', {...});
    document.getElementById('weddingDate').textContent = dateStr;
}
```

**File: `/home/user/bridebuddyv2/api/chat.js` (Lines 101, 133, 155)**
```javascript
// CORRECT - Uses actual column name
if (weddingData.wedding_date) weddingContext += `\n- Wedding Date: ${weddingData.wedding_date}`;
```

**Database Schema: `/home/user/bridebuddyv2/migrations/007_add_missing_wedding_profile_columns.sql` (Line 57-58)**
```sql
IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'wedding_date') THEN
    ALTER TABLE wedding_profiles ADD COLUMN wedding_date DATE;
END IF;
```

### Root Cause
The dashboard was likely developed with a different schema or design specification. The actual column is `wedding_date`, not `ceremony_date`. No `ceremony_date` column exists in the database.

### Fix Required
Change dashboard-luxury.html line 337:
```javascript
// FROM:
if (wedding.ceremony_date) {

// TO:
if (wedding.wedding_date) {
```

Update all 3 references (lines 337-345) to use `wedding.wedding_date`.

---

## ISSUE 2: Trial/Subscription Column Mismatch

### Problem
**Trial and subscription columns don't match between code and database:**

| Expected (Code) | Actual (Database) | Type | Notes |
|---|---|---|---|
| `wedding.subscription_tier` | ❌ Doesn't exist | - | Should be `plan_type` |
| `wedding.trial_ends_at` | ❌ Doesn't exist | - | Should be `trial_end_date` |
| `wedding.is_vip` | ✓ EXISTS | BOOLEAN | Correct |
| `wedding.trial_end_date` | ✓ EXISTS | TIMESTAMPTZ | Correct |

### Impact
Dashboard trial badge fails to display:
- Code tries to access `wedding.subscription_tier` ← undefined
- Code tries to access `wedding.trial_ends_at` ← undefined
- Silent failure, no badge shown or wrong logic

### Code References
**File: `/home/user/bridebuddyv2/public/dashboard-luxury.html` (Lines 295-310)**
```javascript
function updateTrialBadge(wedding) {
    const badge = document.getElementById('trialBadge');
    if (!wedding) return;

    // WRONG - subscription_tier doesn't exist
    if (wedding.subscription_tier === 'trial') {
        // WRONG - trial_ends_at doesn't exist
        const trialEnds = new Date(wedding.trial_ends_at);
        ...
    } else if (wedding.subscription_tier === 'premium') {
        // WRONG - subscription_tier doesn't exist
        badge.textContent = 'Premium';
```

**Database Actual Columns: `/home/user/bridebuddyv2/migrations/007_add_missing_wedding_profile_columns.sql` (Lines 159-164, 171-173)**
```sql
ALTER TABLE wedding_profiles ADD COLUMN plan_type TEXT CHECK (plan_type IN ('trial', 'free', 'basic', 'premium', 'enterprise'));
ALTER TABLE wedding_profiles ADD COLUMN subscription_status TEXT CHECK (subscription_status IN ('trialing', 'active', 'past_due', 'canceled', 'unpaid'));
ALTER TABLE wedding_profiles ADD COLUMN is_vip BOOLEAN DEFAULT FALSE;
ALTER TABLE wedding_profiles ADD COLUMN trial_end_date TIMESTAMPTZ;
```

### Root Cause
The dashboard was using planned column names that differ from actual implementation. The database uses:
- `plan_type` (not `subscription_tier`)
- `trial_end_date` (not `trial_ends_at`)
- `subscription_status` (additional status field)

### Fix Required
**File: `/home/user/bridebuddyv2/public/dashboard-luxury.html`**

Change lines 295-310:
```javascript
// FROM:
if (wedding.subscription_tier === 'trial') {
    const trialEnds = new Date(wedding.trial_ends_at);

// TO:
if (wedding.plan_type === 'trial') {
    const trialEnds = new Date(wedding.trial_end_date);

// FROM:
} else if (wedding.subscription_tier === 'premium') {

// TO:
} else if (wedding.plan_type === 'premium') {
```

---

## ISSUE 3: Missing RLS Permissions for Partner to View Shared Data

### Problem
**Current RLS policies for extraction tables (vendor_tracker, budget_tracker, wedding_tasks) restrict access to owner + partner role, BUT:**

The dashboard loads data as the authenticated user, and the RLS policies are correctly configured. However, there's a **subtle issue with bestie access**:

- Besties should NOT see vendor_tracker, budget_tracker, or wedding_tasks
- The policies correctly prevent this (besties are not in `role IN ('owner', 'partner')`)
- BUT the code doesn't communicate this clearly

### Current RLS Implementation
**File: `/home/user/bridebuddyv2/migrations/014_correct_wedding_architecture.sql` (Lines 165-211)**

```sql
CREATE POLICY "Wedding owners can view vendors"
ON vendor_tracker FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = vendor_tracker.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')  ← Key restriction
  )
);

-- Similar policies for: budget_tracker, wedding_tasks
```

### Impact
- **For owner/partner:** ✓ Can see all extraction data
- **For bestie:** ✗ Cannot see extraction data (by design)
- **For co_planner (if exists):** ✗ Cannot see extraction data

This is **CORRECT by design**, but:
1. Dashboard doesn't handle the permission error gracefully
2. Empty state message doesn't explain "You don't have permission to view this"

### Code Reference
**File: `/home/user/bridebuddyv2/public/dashboard-luxury.html` (Lines 391-448)**
```javascript
async function loadConfirmedVendors() {
    try {
        const { data: vendors, error } = await supabase
            .from('vendor_tracker')
            .select('vendor_type, vendor_name, deposit_paid')
            .eq('wedding_id', weddingId)
            .in('status', ['booked', 'contract_signed', 'deposit_paid', 'fully_paid'])
            .order('vendor_type');

        if (error) throw error;  // ← Silent failure: RLS error thrown but not logged
        
        vendorList.innerHTML = '';
        if (!vendors || vendors.length === 0) {
            vendorList.style.display = 'none';
            emptyState.style.display = 'block';  // ← Shows generic "No vendors" instead of permission error
            return;
        }
    } catch (error) {
        console.error('Error loading confirmed vendors:', error);
        vendorList.style.display = 'none';
        emptyState.style.display = 'block';  // ← Same empty state for both "no data" and "no permission"
    }
}
```

### Root Cause
RLS policies are correctly designed but UI doesn't differentiate between:
1. "No vendors booked" (empty result set)
2. "You don't have permission" (RLS rejection)

### Note on Owner/Partner Distinction
The database correctly supports:
- **owner**: Original wedding creator, full permissions
- **partner**: Co-owner invited to wedding, same permissions as owner
- Both share access to all extraction data (vendor_tracker, budget_tracker, wedding_tasks)

---

## ISSUE 4: Dashboard Widgets Show Empty State - Root Causes

### Why Vendors Widget Shows Nothing

#### Scenario A: User is a Bestie (Not Owner/Partner)
1. Bestie logs in and views dashboard
2. Dashboard tries to query `vendor_tracker` with authenticated user's token
3. RLS policy checks: `role IN ('owner', 'partner')` ← BESTIE fails this check
4. Query returns 0 rows (RLS silently filters)
5. Dashboard shows empty state: "No vendors booked yet"
6. **Actual reason:** Bestie cannot see vendor data (by design)

#### Scenario B: No Vendors Actually Booked
1. Owner logs in and views dashboard
2. Dashboard queries `vendor_tracker` successfully
3. No rows exist where `status IN ('booked', 'contract_signed', ...)`
4. Query returns 0 rows (legitimate empty result)
5. Dashboard shows empty state: "No vendors booked yet"
6. **Actual reason:** No vendors have been bookmarked

#### Scenario C: Chat Extraction Failed Silently
1. User sends message to AI chat
2. AI extraction processes message
3. Claude extracts vendor data: `{"vendor_type": "photographer", "vendor_name": "John Smith", ...}`
4. chat.js tries to insert with `supabaseService.from('vendor_tracker').insert(...)`
5. Insert uses SERVICE_ROLE client, which bypasses RLS ✓ (should succeed)
6. If error occurs (bad column name, FK constraint, etc.), it's caught and logged
7. Dashboard shows empty state (data was never inserted)

### Why Tasks Widget Shows Nothing

Same scenarios as vendors, but for `wedding_tasks` table:

**File: `/home/user/bridebuddyv2/public/dashboard-luxury.html` (Lines 451-505)**
```javascript
async function loadNextToDo() {
    try {
        const { data: tasks, error } = await supabase
            .from('wedding_tasks')
            .select('task_name, due_date')
            .eq('wedding_id', weddingId)
            .neq('status', 'completed')
            .order('due_date', { ascending: true, nullsLast: true })
            .limit(3);

        if (error) throw error;  // ← RLS error silently caught
        
        if (!tasks || tasks.length === 0) {
            // Shows generic empty state, doesn't distinguish between:
            // - No permission to view tasks (RLS rejected)
            // - No tasks created
            // - All tasks are completed
            taskList.style.display = 'none';
            emptyState.style.display = 'block';
        }
    } catch (error) {
        console.error('Error loading next to-do:', error);  // ← Logged but not shown to user
        taskList.style.display = 'none';
        emptyState.style.display = 'block';
    }
}
```

### Actual Data Flow Check

To verify data is being written, check:
1. Are vendors being extracted by chat? → Check `vendor_tracker` table for entries
2. Are tasks being extracted? → Check `wedding_tasks` table for entries
3. Is the user owner/partner? → Check `wedding_members.role` for user_id
4. What's the RLS error? → Check browser console or Supabase logs

---

## Chat Functionality & Extraction Flow

### How Chat Writes Data

**File: `/home/user/bridebuddyv2/api/chat.js` (Lines 269-422)**

```javascript
// Step 1: Parse Claude's response
const responseMatch = fullResponse.match(/<response>([\s\S]*?)<\/response>/);
const dataMatch = fullResponse.match(/<extracted_data>([\s\S]*?)<\/extracted_data>/);

let extractedData = { wedding_info: {}, vendors: [], budget_items: [], tasks: [] };
if (dataMatch) {
    extractedData = JSON.parse(dataMatch[1].trim());
}

// Step 2: Update wedding_profiles with wedding info
if (extractedData.wedding_info && Object.keys(extractedData.wedding_info).length > 0) {
    const weddingUpdates = {};
    Object.keys(extractedData.wedding_info).forEach(key => {
        if (extractedData.wedding_info[key] !== null) {
            weddingUpdates[key] = extractedData.wedding_info[key];  ← Keys must match column names
        }
    });
    
    await supabaseService
        .from('wedding_profiles')
        .update(weddingUpdates)
        .eq('id', membership.wedding_id);
}

// Step 3: Insert vendors
for (const vendor of extractedData.vendors) {
    const { error: vendorInsertError } = await supabaseService
        .from('vendor_tracker')
        .insert({
            wedding_id: membership.wedding_id,
            ...vendor  ← All fields from Claude's extraction must match table columns
        });
}

// Step 4: Insert tasks
for (const task of extractedData.tasks) {
    const { error: taskInsertError } = await supabaseService
        .from('wedding_tasks')
        .insert({
            wedding_id: membership.wedding_id,
            ...task  ← All fields from Claude's extraction must match table columns
        });
}

// Step 5: Save messages to chat_messages (SEPARATE from extraction)
await supabaseService
    .from('chat_messages')
    .insert({
        wedding_id: membership.wedding_id,
        user_id: user.id,
        role: 'user',
        message: message,
        message_type: 'main'  ← Stores user message, not extracted data
    });
```

### Chat Message Storage (Separate from Extraction)

**Important:** Chat messages are stored separately from extracted data:

**chat_messages table:**
- Stores user questions and AI responses as text
- Includes `role` ('user' or 'assistant') and `message_type` ('main' or 'bestie')
- Messages loaded with: `select('*').eq('message_type', 'main')`
- RLS policy: User can only see their own messages

**vendor_tracker, budget_tracker, wedding_tasks tables:**
- Store extracted structured data
- Not linked to individual chat messages
- Shared across owner/partner (not per-user)

---

## Bestie Chat & Permissions

### How Bestie Chat Works

**File: `/home/user/bridebuddyv2/api/bestie-chat.js` (Lines 1-354)**

Bestie chat is similar to main chat but:

1. **Only extracts to budget_items and tasks:**
   - Does NOT extract to wedding_profiles (bestie shouldn't modify core wedding data)
   - Does NOT extract to vendor_tracker (bestie isn't managing vendors)

2. **Message type is 'bestie':**
   - `message_type: 'bestie'` stores messages separately

3. **RLS Permissions:**
   - Bestie CAN view wedding_members (to see who's in wedding)
   - Bestie CANNOT view vendor_tracker (owner permission required)
   - Bestie CANNOT view budget_tracker (owner permission required)
   - Bestie CANNOT view wedding_tasks (owner permission required)
   - Bestie CAN view bestie_profile (their own profile)

### User Roles and Permissions

**File: `/home/user/bridebuddyv2/migrations/014_correct_wedding_architecture.sql` (Lines 109-115)**

```sql
ALTER TABLE wedding_members
DROP CONSTRAINT IF EXISTS wedding_members_role_check;

ALTER TABLE wedding_members
ADD CONSTRAINT wedding_members_role_check
CHECK (role IN ('owner', 'partner', 'bestie'));
```

| Role | Max per Wedding | Chat Access | Vendor Access | Budget Access | Task Access |
|---|---|---|---|---|---|
| **owner** | 1 | Main chat only | ✓ Read/Write | ✓ Read/Write | ✓ Read/Write |
| **partner** | 1 | Main chat only | ✓ Read/Write | ✓ Read/Write | ✓ Read/Write |
| **bestie** | 2 | Bestie chat only | ✗ Cannot see | ✗ Cannot see | ✗ Cannot see |

### Why Bestie Cannot See Vendor/Budget/Task Data

The RLS policies explicitly check:
```sql
AND wedding_members.role IN ('owner', 'partner')
```

This is **intentional design** - besties plan their own activities (bachelor/bachelorette parties) separately from the main wedding planning.

---

## Summary of All Issues

| Issue | Severity | File(s) | Impact | Status |
|---|---|---|---|---|
| **wedding_date column mismatch** | 🔴 CRITICAL | dashboard-luxury.html | Countdown never displays | Not fixed |
| **subscription_tier / trial_ends_at mismatch** | 🔴 CRITICAL | dashboard-luxury.html | Trial badge never displays | Not fixed |
| **RLS permission errors not handled** | 🟡 MEDIUM | dashboard-luxury.html | UI shows generic "no data" instead of permission denied | Not fixed |
| **Bestie cannot see extraction data** | 🟢 WORKING AS DESIGNED | N/A | Besties see empty widgets | Not an issue |

---

## Recommended Fixes (Priority Order)

### 1. Fix Wedding Date Column Reference (dashboard-luxury.html)
```diff
- if (wedding.ceremony_date) {
-     const days = calculateDaysUntil(wedding.ceremony_date);
+ if (wedding.wedding_date) {
+     const days = calculateDaysUntil(wedding.wedding_date);
      document.getElementById('daysUntil').textContent = days > 0 ? days : '0';
-     const dateStr = new Date(wedding.ceremony_date).toLocaleDateString('en-US', {
+     const dateStr = new Date(wedding.wedding_date).toLocaleDateString('en-US', {
```

### 2. Fix Trial Badge Logic (dashboard-luxury.html)
```diff
function updateTrialBadge(wedding) {
     const badge = document.getElementById('trialBadge');
     if (!wedding) return;

-    if (wedding.subscription_tier === 'trial') {
-        const trialEnds = new Date(wedding.trial_ends_at);
+    if (wedding.plan_type === 'trial') {
+        const trialEnds = new Date(wedding.trial_end_date);
         ...
-    } else if (wedding.subscription_tier === 'premium') {
+    } else if (wedding.plan_type === 'premium') {
```

### 3. Add Better Error Messages (dashboard-luxury.html)
```javascript
// After catch block in loadConfirmedVendors()
catch (error) {
    console.error('Error loading confirmed vendors:', error);
    
    // Check if it's an RLS error
    if (error.code === 'PGRST116' || error.message.includes('permission denied')) {
        emptyVendors.innerHTML = `
            <div class="empty-state-icon">🔒</div>
            <h4 class="empty-state-title">Vendors not visible</h4>
            <p class="empty-state-description">
                Only the wedding owner or partner can view vendor information.
            </p>
        `;
    }
    vendorList.style.display = 'none';
    emptyState.style.display = 'block';
}
```

---

## Testing & Verification

### Verify Data Extraction is Working
1. Log in as owner/partner
2. Go to chat page (chat-luxury.html)
3. Send message: "I booked John Smith as photographer for $3000"
4. Open browser DevTools → Network tab → /api/chat request
5. Verify response includes `extractedData` with vendor data

### Verify Dashboard Displays Data
1. After extraction, go to dashboard (dashboard-luxury.html)
2. Scroll to "Confirmed Vendors" section
3. Should see "Photographer - John Smith" with ✓ indicator

### Verify RLS Permissions
1. Create second user as "bestie"
2. Log in as bestie
3. Go to dashboard → Confirmed Vendors should show empty state
4. Open browser console and check for errors
5. Should see permission-related errors if bestie tries direct API access

---

## Schema Reference

### wedding_profiles (Main Wedding Data)
```
wedding_date          DATE               ← Chat reads/writes here
ceremony_location     TEXT
reception_location    TEXT
venue_name            TEXT
expected_guest_count  INTEGER
total_budget          NUMERIC(10,2)
wedding_style         TEXT
color_scheme_primary  TEXT
partner1_name         TEXT
partner2_name         TEXT
wedding_time          TIME
wedding_name          TEXT
plan_type             TEXT (trial|free|basic|premium|enterprise)  ← Use instead of subscription_tier
trial_end_date        TIMESTAMPTZ        ← Use instead of trial_ends_at
is_vip                BOOLEAN
```

### vendor_tracker (Extracted Vendor Data)
```
wedding_id            UUID
vendor_type           TEXT
vendor_name           TEXT
total_cost            NUMERIC(10,2)
deposit_paid          BOOLEAN
status                TEXT
service_date          DATE
```

### wedding_tasks (Extracted Task Data)
```
wedding_id            UUID
task_name             TEXT
due_date              DATE
status                TEXT (not_started|in_progress|completed|cancelled)
priority              TEXT (low|medium|high|urgent)
category              TEXT
```

### chat_messages (Chat History)
```
wedding_id            UUID
user_id               UUID
message               TEXT
role                  TEXT (user|assistant)
message_type          TEXT (main|bestie)
created_at            TIMESTAMPTZ
```


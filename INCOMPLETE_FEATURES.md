# Incomplete Features Documentation

This document catalogs features that have UI elements or database infrastructure but lack complete implementation. These are **intentional placeholders** for future development, not bugs.

---

## Summary

| Feature | Status | UI | Database | Backend | Impact |
|---------|--------|----|----|---------|---------|
| Bestie Utility Buttons | ❌ Not Implemented | ✅ Present | ✅ Tables exist | ❌ No endpoints | Users see "coming soon" |
| Pending Updates Workflow | ❌ Not Functional | ✅ Present | ✅ Table exists | ⚠️ Read-only | Approval UI shows no data |
| Bestie Profile Auto-Update | ❌ Not Implemented | ✅ Manual edit works | ✅ Table exists | ⚠️ No auto-update | Default brief never changes |

---

## 1. Bestie Utility Buttons (Events, Bridesmaids, Payments)

### Current State
**Location:** `/public/bestie-luxury.html` (lines 111-119, 243-256)

**UI Elements:**
- "Manage Events" button
- "Bridesmaid Tracker" button
- "Payment Tracking" button

**Current Behavior:**
```javascript
window.viewEvents = function() {
    showToast('Events management coming soon! For now, ask me in the chat about managing your events.', 'info');
    toggleMenu();
};

window.viewBridesmaids = function() {
    showToast('Bridesmaid tracker coming soon! For now, ask me in the chat about tracking bridesmaids.', 'info');
    toggleMenu();
};

window.viewPayments = function() {
    showToast('Payment tracking coming soon! For now, ask me in the chat about tracking payments.', 'info');
    toggleMenu();
};
```

**User Experience:**
- User clicks button → Toast notification → "Coming soon" message
- User is directed to ask in chat instead
- No backend functionality exists

---

### What Would Need to Be Implemented

#### 1.1 Events Management
**Purpose:** Track bachelorette/bachelor parties, bridal showers, rehearsal dinners

**Database Tables:**
- `bestie_events` (new table needed)
  ```sql
  CREATE TABLE bestie_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wedding_id UUID REFERENCES wedding_profiles(id) ON DELETE CASCADE,
    bestie_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT CHECK (event_type IN ('bachelorette', 'bachelor', 'bridal_shower', 'rehearsal_dinner', 'other')),
    event_name TEXT NOT NULL,
    event_date TIMESTAMPTZ,
    event_location TEXT,
    budget DECIMAL(10,2),
    spent DECIMAL(10,2) DEFAULT 0,
    guest_count INTEGER,
    status TEXT CHECK (status IN ('planning', 'booked', 'completed', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );
  ```

**API Endpoints Needed:**
- `POST /api/bestie/events` - Create new event
- `GET /api/bestie/events?wedding_id=<id>` - List events
- `PUT /api/bestie/events/:id` - Update event
- `DELETE /api/bestie/events/:id` - Delete event

**UI Pages Needed:**
- `events-luxury.html` - Event list and detail view
- Event creation modal
- Event edit form
- Budget tracker for each event

---

#### 1.2 Bridesmaid Tracker
**Purpose:** Track bridesmaid dress orders, measurements, payments, availability

**Database Tables:**
- `bridesmaids` (new table needed)
  ```sql
  CREATE TABLE bridesmaids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wedding_id UUID REFERENCES wedding_profiles(id) ON DELETE CASCADE,
    bestie_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    role TEXT CHECK (role IN ('maid_of_honor', 'bridesmaid', 'junior_bridesmaid')),
    dress_size TEXT,
    dress_ordered BOOLEAN DEFAULT false,
    dress_paid BOOLEAN DEFAULT false,
    dress_amount DECIMAL(10,2),
    availability_bachelorette BOOLEAN,
    availability_shower BOOLEAN,
    availability_rehearsal BOOLEAN,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );
  ```

**API Endpoints Needed:**
- `POST /api/bestie/bridesmaids` - Add bridesmaid
- `GET /api/bestie/bridesmaids?wedding_id=<id>` - List bridesmaids
- `PUT /api/bestie/bridesmaids/:id` - Update bridesmaid info
- `DELETE /api/bestie/bridesmaids/:id` - Remove bridesmaid

**UI Pages Needed:**
- `bridesmaids-luxury.html` - Bridesmaid list and tracker
- Add/edit bridesmaid modal
- Dress order checklist
- Availability calendar view

---

#### 1.3 Payment Tracking
**Purpose:** Track contributions, reimbursements, and shared expenses for bestie-organized events

**Database Tables:**
- `bestie_payments` (new table needed)
  ```sql
  CREATE TABLE bestie_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wedding_id UUID REFERENCES wedding_profiles(id) ON DELETE CASCADE,
    bestie_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    event_id UUID REFERENCES bestie_events(id) ON DELETE CASCADE,
    payment_type TEXT CHECK (payment_type IN ('expense', 'contribution', 'reimbursement')),
    description TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    paid_by TEXT, -- Name of person who paid
    paid_to TEXT, -- Name of recipient
    date TIMESTAMPTZ DEFAULT NOW(),
    status TEXT CHECK (status IN ('pending', 'paid', 'reimbursed')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );
  ```

**API Endpoints Needed:**
- `POST /api/bestie/payments` - Record payment
- `GET /api/bestie/payments?wedding_id=<id>` - List payments
- `PUT /api/bestie/payments/:id` - Update payment
- `DELETE /api/bestie/payments/:id` - Delete payment
- `GET /api/bestie/payments/summary?wedding_id=<id>` - Get payment summary

**UI Pages Needed:**
- `payments-luxury.html` - Payment tracker
- Add payment modal
- Reimbursement calculator
- Split expense calculator
- Summary dashboard (who owes what)

---

### Implementation Priority
**Status:** LOW - These are convenience features, not core functionality
**Workaround:** Users can track these items via chat conversation
**Effort:** HIGH - Each feature requires new table, API endpoints, and UI pages

---

## 2. Pending Updates Approval Workflow

### Current State
**Location:** Database table exists, UI exists, but no write mechanism

**Database Table:** `pending_updates`
```sql
CREATE TABLE pending_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**UI:** `/public/notifications-luxury.html`
- Displays pending updates
- Allows owners to approve/reject
- Shows update details in modal

**API:** `/api/approve-update.js`
- Reads from `pending_updates`
- Updates status to 'approved' or 'rejected'
- Applies approved changes to `wedding_profiles`

**Problem:** **No code writes to `pending_updates`**

---

### What Happens Currently

1. **User opens notifications page** → Query returns empty result set
2. **No pending updates exist** → UI shows "No pending updates"
3. **Approval workflow cannot be tested** → Table always empty

**Search Results:**
```bash
$ grep -r "pending_updates.*insert" api/
# No results

$ grep -r "\.from('pending_updates')\.insert" .
# No results
```

**Only references:**
- `api/approve-update.js` - Reads and updates status (lines 49-101)
- `database_init.sql` - Table schema and RLS policies
- `SCHEMA_RLS_ANALYSIS.md` - Documentation (aspirational)

---

### Original Design Intent

**From SCHEMA_RLS_ANALYSIS.md (line 561):**
> "⚠️ Currently only AI creates pending updates (in chat.js)"

**This statement is INCORRECT** - `api/chat.js` does NOT write to `pending_updates`

**Intended Workflow:**
1. Co-planner or bestie suggests change in chat
2. AI extracts proposed update
3. Backend writes to `pending_updates` with status='pending'
4. Owner sees notification
5. Owner approves or rejects
6. If approved, backend applies change to `wedding_profiles`

---

### What Would Need to Be Implemented

#### Option A: AI-Driven Pending Updates (Original Intent)

**Modify `/api/chat.js` to detect permission boundaries:**

```javascript
// After extracting wedding_info updates
if (extractedData.wedding_info && Object.keys(extractedData.wedding_info).length > 0) {

  // Check if user has permission to edit directly
  const userRole = membership.role;
  const requiresApproval = (userRole === 'partner'); // Partners need approval for critical fields

  if (requiresApproval) {
    // Write to pending_updates instead of direct update
    for (const [fieldName, newValue] of Object.entries(extractedData.wedding_info)) {
      const { data: currentWedding } = await supabaseService
        .from('wedding_profiles')
        .select(fieldName)
        .eq('id', membership.wedding_id)
        .single();

      const oldValue = currentWedding ? currentWedding[fieldName] : null;

      await supabaseService
        .from('pending_updates')
        .insert({
          wedding_id: membership.wedding_id,
          user_id: user.id,
          field_name: fieldName,
          old_value: oldValue ? String(oldValue) : null,
          new_value: String(newValue),
          status: 'pending'
        });
    }

    // Notify user that changes are pending approval
    assistantMessage += '\n\n⏳ Your proposed changes have been submitted for approval by the wedding owner.';

  } else {
    // Owner can update directly (existing code)
    const { error: updateError } = await supabaseService
      .from('wedding_profiles')
      .update(extractedData.wedding_info)
      .eq('id', membership.wedding_id);
  }
}
```

**Benefits:**
- Seamless permission enforcement
- Users don't need to know about approval workflow
- AI automatically routes updates correctly

**Complexity:** MEDIUM

---

#### Option B: Manual Pending Update Creation

**Create new endpoint `/api/propose-update.js`:**

```javascript
// Allows partners to explicitly propose changes
export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { userToken, weddingId, fieldName, newValue } = req.body;

  // Authenticate user
  // Check role (must be partner or bestie)
  // Get current value from wedding_profiles
  // Insert into pending_updates
  // Return success
}
```

**New UI:**
- Add "Propose Change" button in settings
- Modal to select field and enter new value
- Confirmation toast

**Benefits:**
- Explicit workflow
- Clear to users when approval is needed

**Complexity:** LOW-MEDIUM

---

### Recommended Implementation

**OPTION A (AI-Driven)** for seamless UX

**Implementation Steps:**
1. Define which fields require approval (e.g., `wedding_date`, `venue_name`, `total_budget`)
2. Modify `/api/chat.js` to check user role before applying updates
3. For partners, write critical field changes to `pending_updates`
4. Add notification badge to dashboard when pending updates exist
5. Test approval workflow end-to-end

**Effort:** MEDIUM (2-3 days)
**Priority:** MEDIUM - Approval workflow is a documented feature but not critical

---

## 3. Bestie Profile Auto-Update from Chat

### Current State
**Location:** `/api/bestie-chat.js` creates profile but never updates it

**Table:** `bestie_profile`
```sql
CREATE TABLE bestie_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bestie_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  wedding_id UUID REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  bestie_brief TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(bestie_user_id, wedding_id)
);
```

**Current Behavior:**
- `/api/bestie-chat.js` (lines 72-93): Creates profile with default brief if it doesn't exist
- Default brief: `"Welcome! Chat with me to start planning your bestie duties and surprises."`
- **Never updates the brief based on chat content**

**User Experience:**
1. Bestie logs in → Profile created with default brief
2. Bestie chats about plans → Brief stays as default
3. Bestie opens "My Bestie Profile" modal → Sees default text
4. Bestie must manually edit to update

---

### What Would Need to Be Implemented

#### Intelligent Brief Generation

**Modify `/api/bestie-chat.js` to extract and update brief:**

```javascript
// After processing chat (around line 242)
if (dataMatch) {
  try {
    const jsonStr = dataMatch[1].trim();
    extractedData = JSON.parse(jsonStr);

    // NEW: Extract brief summary from conversation
    if (message.length > 50) { // Meaningful conversation
      // Ask Claude to generate a brief summary
      const briefResponse = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': process.env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01'
        },
        body: JSON.stringify({
          model: 'claude-sonnet-4-20250514',
          max_tokens: 256,
          messages: [{
            role: 'user',
            content: `Based on this bestie conversation, generate a 2-3 sentence brief about what the bestie is planning. Keep it concise and actionable.

Conversation: "${message}"
Assistant response: "${assistantMessage}"

Brief (2-3 sentences only):`
          }]
        })
      });

      const briefData = await briefResponse.json();
      const generatedBrief = briefData.content[0].text.trim();

      // Update bestie_profile with new brief
      await supabaseService
        .from('bestie_profile')
        .update({
          bestie_brief: generatedBrief,
          updated_at: new Date().toISOString()
        })
        .eq('bestie_user_id', user.id)
        .eq('wedding_id', membership.wedding_id);
    }
  } catch (e) {
    console.error('Failed to parse extracted data:', e);
  }
}
```

**Benefits:**
- Brief automatically stays current
- Reflects actual planning conversation
- No manual editing needed
- Useful summary for besties returning after time away

**Drawbacks:**
- Additional API call per message (cost + latency)
- May overwrite manual edits
- Brief could become stale if conversation shifts topics

---

### Alternative: Periodic Brief Updates

Instead of updating after every message, update only when:
1. Bestie profile modal is opened
2. A significant planning milestone is mentioned (e.g., "booked venue")
3. Manual refresh button is clicked

**Implementation:**
- Add "Refresh Brief" button in bestie profile modal
- On click, summarize recent chat history (last 10 messages)
- Update brief with summary

**Benefits:**
- Lower API costs
- User control over updates
- Preserves manual edits until refresh

**Complexity:** LOW-MEDIUM

---

### Recommended Implementation

**Periodic Brief Updates (via Refresh Button)**

**Implementation Steps:**
1. Add "Refresh Brief from Chat" button to profile modal
2. Create `/api/bestie/refresh-brief.js` endpoint
3. Fetch last 10-20 bestie chat messages
4. Generate summary via Claude
5. Update `bestie_profile.bestie_brief`
6. Return new brief to UI

**Effort:** LOW (1 day)
**Priority:** LOW - Manual editing works fine as fallback

---

## Summary & Recommendations

| Feature | Priority | Effort | Recommended Action |
|---------|----------|--------|-------------------|
| Bestie Utility Buttons | LOW | HIGH | Keep as placeholder, document workaround |
| Pending Updates Workflow | MEDIUM | MEDIUM | Implement AI-driven insertion in chat.js |
| Bestie Profile Auto-Update | LOW | LOW | Add "Refresh Brief" button |

### Next Steps for Production

1. **Document "Coming Soon" Features** ✅ (This file)
2. **Implement Pending Updates** (Priority: MEDIUM)
   - Modify `/api/chat.js` to write to `pending_updates` for partners
   - Test approval workflow end-to-end
   - Add notification badge to dashboard
3. **Add Bestie Brief Refresh** (Priority: LOW)
   - Quick win, improves UX
   - Low effort, low risk
4. **Plan Bestie Utilities** (Priority: LOW)
   - Future enhancement
   - Can be phase 2 after MVP launch

---

## Developer Notes

### Testing Pending Updates

To manually test the approval workflow, insert test data:

```sql
-- Insert test pending update
INSERT INTO pending_updates (wedding_id, user_id, field_name, old_value, new_value, status)
SELECT
  wm.wedding_id,
  wm.user_id,
  'wedding_date',
  '2025-06-15',
  '2025-07-20',
  'pending'
FROM wedding_members wm
WHERE wm.role = 'partner'
LIMIT 1;
```

Then visit `/notifications-luxury.html` to see it appear and test approval.

### Testing Bestie Profile

To test auto-update without implementing:

```sql
-- Manually update brief
UPDATE bestie_profile
SET bestie_brief = 'Planning bachelorette in Miami, June 10-12. Booked Airbnb, need to send invites.'
WHERE bestie_user_id = '<USER_ID>';
```

Then open profile modal to see updated brief.

---

**Last Updated:** 2025-10-28
**Author:** Claude Code
**Status:** Production Documentation

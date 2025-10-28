# Frontend ↔ Backend Alignment Documentation

## Overview
This document clarifies how the frontend and backend interact, highlighting architectural decisions and potential gaps.

---

## 1. Signup & Profile Creation

### Current Flow
```
User signs up → supabase.auth.signUp() → auth.users table created
                                       ↓
                              (Optional trigger: handle_new_user)
                                       ↓
                              profiles table entry created
                                       ↓
User completes onboarding → /api/create-wedding called
                                       ↓
                              wedding_profiles + wedding_members created
```

### Key Points
- **Trigger**: `handle_new_user` in `database_init.sql` auto-creates profile entries
- **Migration**: Now included in `migrations/016_add_profile_trigger_optional.sql`
- **Fallback**: APIs (`create-wedding.js`, `accept-invite.js`) now check and create profiles if missing
- **Status**: ✅ **RESILIENT** - Works with or without trigger deployed

### Why This Matters
Deployments that skip triggers (e.g., Supabase migrations-only) won't break signup flow because APIs handle profile creation as a fallback.

---

## 2. Wedding Chat → Database Updates

### Data Flow
```
User message → /api/chat → Claude AI extraction → Multiple table updates
```

### Tables Updated by Wedding Chat
| Table | Fields Updated | Purpose |
|-------|----------------|---------|
| `wedding_profiles` | wedding_date, partner names, venue, budget, style, etc. | Core wedding details |
| `vendor_tracker` | vendor_type, vendor_name, costs, status, etc. | Vendor management |
| `budget_tracker` | category, budgeted_amount, spent_amount, transactions | Budget tracking |
| `wedding_tasks` | task_name, due_date, status, priority | Task management |

### Who Can Use Wedding Chat
- ✅ Owner (role='owner')
- ✅ Partner (role='partner')
- ❌ Bestie (role='bestie') - **blocked** and redirected to bestie chat

**Implementation**: `api/chat.js:67-73` checks role and returns 403 for besties.

---

## 3. Bestie Chat → Database Updates

### Data Flow
```
Bestie message → /api/bestie-chat → Claude AI extraction → Limited table updates
```

### Tables Updated by Bestie Chat
| Table | Fields Updated | Purpose |
|-------|----------------|---------|
| `budget_tracker` | category, budgeted_amount, spent_amount (bestie events) | Bestie event budgets |
| `wedding_tasks` | task_name, due_date, status (bestie duties) | Bestie task tracking |
| `bestie_profile` | (auto-created if missing) | Ensures profile exists |

### Bestie Profile (`bestie_profile.bestie_brief`) Updates

**Two Update Paths**:

1. **Manual Update (Client-Side)**
   - File: `public/bestie-luxury.html:323-331`
   - Method: Direct Supabase client update with RLS
   - Security: RLS policy "Bestie can update own profile" enforces `bestie_user_id = auth.uid()`
   - Status: ✅ **WORKING**

2. **AI Chat Extraction (Not Implemented)**
   - The bestie chat API does NOT extract or update the `bestie_brief` field from conversation
   - Unlike wedding chat which auto-updates `wedding_profiles` fields
   - Architectural decision: brief is a settings field, not conversational data
   - Status: ⚠️ **BY DESIGN** - Profile settings managed separately from chat

---

## 4. Dashboard Widget Data Sources

### Dashboard Reads (All Working)
| Widget | Table | Columns |
|--------|-------|---------|
| Budget Overview | `budget_tracker` | budgeted_amount, spent_amount, remaining_amount |
| Vendor List | `vendor_tracker` | vendor_name, vendor_type, status, total_cost |
| Task Checklist | `wedding_tasks` | task_name, due_date, status, assigned_to |
| Wedding Details | `wedding_profiles` | wedding_date, venue_name, guest_count, style |

**Status**: ✅ All widgets query the correct tables defined in migrations.

---

## 5. Notifications & Pending Updates System

### Architecture
```
pending_updates table → approve-update.js (API) → notifications-luxury.html (UI)
```

### Current Status: ⚠️ **ORPHANED FUNCTIONALITY**

#### Why It's Unused
The `pending_updates` table was designed for a **co-planner role with limited permissions** that would:
1. Submit proposed changes to wedding data
2. Owner/partner would approve or reject
3. Changes would apply to wedding_profiles upon approval

#### Current Role Architecture (Migration 014)
```sql
CHECK (role IN ('owner', 'partner', 'bestie'))
```

**No co-planner role exists!** All current roles have write access:
- **Owner**: Full write access to wedding_profiles
- **Partner**: Full write access to wedding_profiles
- **Bestie**: Write access to bestie-specific tables only

#### Missing Code Path
**No API endpoint inserts into `pending_updates`**:
```bash
$ grep -r "pending_updates.*insert" api/
# No results
```

The only references are:
- `api/approve-update.js` - **reads** from pending_updates (approves/rejects)
- `public/notifications-luxury.html` - **reads** from pending_updates (displays)

#### Impact
- Notifications screen will always be empty
- Approval workflow is non-functional
- No harm to existing functionality

#### Options to Fix
**Option A**: Remove orphaned code
- Delete `pending_updates` table
- Remove `api/approve-update.js`
- Remove notifications UI

**Option B**: Implement permissions system
- Add `wedding_profile_permissions` JSONB to `wedding_members`
- Add middleware to chat API to check permissions
- Route restricted updates through pending_updates
- This was the original design but never fully implemented

**Option C**: Leave as-is (current state)
- Table exists but unused
- Future-proofs for potential permissions system
- No negative impact on performance

**Recommendation**: **Option C** - Keep for future use, document as unused.

---

## 6. RLS Policies & Security

### bestie_profile RLS Policies
Located in: `database_init.sql:619-649`

```sql
-- Besties can manage their own profiles
CREATE POLICY "Bestie can view own profile" ON bestie_profile FOR SELECT
  USING (bestie_user_id = auth.uid());

CREATE POLICY "Bestie can update own profile" ON bestie_profile FOR UPDATE
  USING (bestie_user_id = auth.uid());

-- Wedding members can view (read-only) bestie profiles
CREATE POLICY "Wedding members can view bestie profiles" ON bestie_profile FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_id = bestie_profile.wedding_id
    AND user_id = auth.uid()
  ));
```

**Implications**:
- Bestie brief updates work client-side (no API needed)
- Owner/partner can view but not edit bestie profiles
- Service role (API endpoints) has full access for auto-creation

---

## 7. Migration vs Database_init.sql

### Trigger Deployment
- **database_init.sql**: Contains `handle_new_user` trigger (lines 99-116)
- **migrations/**: NOW includes `016_add_profile_trigger_optional.sql`
- **Why both?**: `database_init.sql` is for fresh deploys, migrations are for updates

### Deployment Scenarios
| Scenario | Trigger Deployed? | Works? | Why |
|----------|-------------------|--------|-----|
| Fresh deploy with database_init.sql | ✅ Yes | ✅ Yes | Trigger auto-creates profiles |
| Migration-only deploy (skip trigger) | ❌ No | ✅ Yes | APIs create profiles as fallback |
| Migration 016 applied | ✅ Yes | ✅ Yes | Trigger + API fallback (belt & suspenders) |

---

## 8. Summary of Fixes Applied

### Fixed Issues
1. ✅ **Signup profile creation** - APIs now ensure profiles exist
2. ✅ **Chat access control** - Besties blocked from wedding chat
3. ✅ **Bestie profile creation** - Auto-created when bestie uses chat
4. ✅ **Notifications payload** - Fixed to match API expectations
5. ✅ **Trigger migration** - Added to migrations set (optional/backup)

### Documented Non-Issues
1. ℹ️ **Bestie brief persistence** - Works via client-side RLS (by design)
2. ℹ️ **Pending updates empty** - No co-planner role exists (orphaned feature)

### Remaining Gaps (Future Work)
1. **Permissions system not implemented** - All roles have full write access
2. **Pending updates table unused** - Could be removed or implemented fully
3. **No audit trail** - Changes aren't tracked (pending_updates would have provided this)

---

## 9. Testing Recommendations

### Critical Paths to Test
1. **Signup flow without trigger**:
   - Deploy without running database_init.sql trigger section
   - Sign up new user
   - Verify profile created by API
   - Complete onboarding
   - Verify wedding_profiles created

2. **Bestie chat isolation**:
   - Accept bestie invite
   - Try to access /chat-luxury.html
   - Verify redirect or access block
   - Use /bestie-luxury.html instead
   - Verify bestie_profile auto-created

3. **Profile settings persistence**:
   - As bestie, update "About Me" brief
   - Refresh page
   - Verify brief persisted

4. **Notifications screen**:
   - Log in as owner
   - Visit notifications page
   - Expected: Empty state (no pending updates)
   - This is correct behavior given current architecture

---

## 10. Architecture Decisions Summary

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Profile creation in APIs | Resilient to trigger deployment issues | Safer deployments |
| Bestie brief via client RLS | Reduces API calls, simpler architecture | Besties update directly |
| No co-planner permissions | Simplified architecture (owner + partner + bestie) | All roles have write access |
| Pending updates unused | No limited-permission roles exist | Notifications empty but harmless |
| Chat extraction different by role | Wedding chat = comprehensive, bestie chat = limited | Proper data separation |

---

**Last Updated**: 2025-10-28
**Migration Version**: 016 (trigger optional)
**API Version**: Chat v2 (with role checking)

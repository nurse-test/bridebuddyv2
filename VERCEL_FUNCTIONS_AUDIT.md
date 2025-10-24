# VERCEL SERVERLESS FUNCTIONS AUDIT

**Audit Date:** 2025-10-24
**Vercel Plan Limit:** 12 functions
**Current Count:** 14 functions
**Status:** ⚠️ **OVER LIMIT BY 2 FUNCTIONS**

---

## 📊 FUNCTION INVENTORY

### Current Functions (14 total)

| # | Function | Method | Purpose | Lines | Status |
|---|----------|--------|---------|-------|--------|
| 1 | `accept-bestie-invite.js` | POST | Accept bestie invite (OLD SYSTEM) | 244 | ⚠️ DEPRECATED |
| 2 | `accept-invite.js` | POST | Accept invite for all roles (UNIFIED) | 270 | ✅ ACTIVE |
| 3 | `approve-update.js` | POST | Approve co-planner update requests | ~150 | ✅ ACTIVE |
| 4 | `bestie-chat.js` | POST | Claude AI chat for bestie planning | ~200 | ✅ ACTIVE |
| 5 | `chat.js` | POST | Claude AI chat for main wedding planning | ~200 | ✅ ACTIVE |
| 6 | `create-bestie-invite.js` | POST | Create bestie invite (OLD SYSTEM) | 183 | ⚠️ DEPRECATED |
| 7 | `create-checkout.js` | POST | Stripe checkout session creation | ~100 | ✅ ACTIVE |
| 8 | `create-invite.js` | POST | Create invite for all roles (UNIFIED) | 204 | ✅ ACTIVE |
| 9 | `create-wedding.js` | POST | Create new wedding profile | ~150 | ✅ ACTIVE |
| 10 | `get-invite-info.js` | GET | Validate and show invite details | 159 | ✅ ACTIVE |
| 11 | `get-my-bestie-permissions.js` | GET | Bestie views inviter's access | 175 | ✅ ACTIVE |
| 12 | `join-wedding.js` | POST | Join wedding with code (OLD SYSTEM) | ~150 | ⚠️ REDUNDANT |
| 13 | `stripe-webhook.js` | POST | Stripe payment webhooks | ~100 | ✅ MUST KEEP |
| 14 | `update-my-inviter-access.js` | POST | Bestie updates inviter permissions | 195 | ✅ ACTIVE |

---

## 🎯 CONSOLIDATION ANALYSIS

### Priority 1: Remove Deprecated Functions ⚡ **QUICK WIN**

**Impact:** Save 3 functions immediately

| Function | Why Deprecated | Safe to Delete? |
|----------|---------------|-----------------|
| `accept-bestie-invite.js` | Replaced by unified `accept-invite.js` | ✅ YES - Check frontend first |
| `create-bestie-invite.js` | Replaced by unified `create-invite.js` | ✅ YES - Check frontend first |
| `join-wedding.js` | Old code-based system, replaced by `accept-invite.js` | ✅ YES - Check frontend first |

**Action Required:**
1. Search frontend for any references to these endpoints
2. If found, update to use new unified endpoints
3. Delete the 3 deprecated files

**Estimated Savings:** 3 functions → **New count: 11 functions** ✅ **UNDER LIMIT**

---

### Priority 2: Consolidate Invite Operations

**Impact:** Save 2 additional functions (buffer for future growth)

**Current Structure (3 functions):**
```
/api/create-invite.js       (POST)
/api/accept-invite.js       (POST)
/api/get-invite-info.js     (GET)
```

**Consolidated Structure (1 function):**
```
/api/invites.js
  - POST with action=create    → create invite
  - POST with action=accept    → accept invite
  - GET                        → get invite info
```

**Estimated Savings:** 2 functions → **New count: 9 functions** ✅ **Safe buffer**

---

### Priority 3: Consolidate Bestie Permission Operations

**Impact:** Save 1 additional function

**Current Structure (2 functions):**
```
/api/get-my-bestie-permissions.js    (GET)
/api/update-my-inviter-access.js     (POST)
```

**Consolidated Structure (1 function):**
```
/api/bestie-permissions.js
  - GET    → get permissions
  - POST   → update permissions
```

**Estimated Savings:** 1 function → **New count: 8 functions** ✅ **Extra buffer**

---

### Priority 4: Consolidate Chat Operations (OPTIONAL)

**Impact:** Save 1 function

**Current Structure (2 functions):**
```
/api/chat.js          (POST) - Main wedding chat
/api/bestie-chat.js   (POST) - Bestie planning chat
```

**Consolidated Structure (1 function):**
```
/api/chat.js
  - POST with context=wedding → main chat
  - POST with context=bestie  → bestie chat
```

**Note:** These might have different AI prompts/contexts, so consolidation is optional.

**Estimated Savings:** 1 function → **New count: 7 functions** ✅ **Maximum buffer**

---

## 📈 CONSOLIDATION ROADMAP

### Phase 1: Quick Wins (Delete Deprecated)
- **Current:** 14 functions
- **Action:** Delete 3 deprecated functions
- **Result:** 11 functions ✅ **UNDER LIMIT**
- **Effort:** 1 hour (verify frontend, delete files)
- **Risk:** Low (if frontend already updated)

### Phase 2: Invite Consolidation (RECOMMENDED)
- **Current:** 11 functions
- **Action:** Consolidate invite operations
- **Result:** 9 functions ✅ **Safe buffer**
- **Effort:** 4 hours (refactor + test)
- **Risk:** Medium (frontend changes required)

### Phase 3: Bestie Permissions Consolidation (OPTIONAL)
- **Current:** 9 functions
- **Action:** Consolidate bestie permissions
- **Result:** 8 functions ✅ **Extra buffer**
- **Effort:** 2 hours (refactor + test)
- **Risk:** Low (simple GET/POST split)

### Phase 4: Chat Consolidation (OPTIONAL)
- **Current:** 8 functions
- **Action:** Consolidate chat endpoints
- **Result:** 7 functions ✅ **Maximum buffer**
- **Effort:** 3 hours (merge logic + test)
- **Risk:** Medium (AI context differences)

---

## ✅ RECOMMENDED IMMEDIATE ACTIONS

### Step 1: Verify Frontend Dependencies

**Check for deprecated endpoint usage:**
```bash
# Search all frontend files
grep -r "create-bestie-invite" public/
grep -r "accept-bestie-invite" public/
grep -r "join-wedding" public/
```

**Expected result:** No matches (already updated to unified system)

### Step 2: Delete Deprecated Functions

```bash
rm api/accept-bestie-invite.js
rm api/create-bestie-invite.js
rm api/join-wedding.js
```

**Result:** **11 functions** ✅ **COMPLIANT**

### Step 3: Test Everything

- Create new invite → ✅ Works via `create-invite.js`
- Accept invite → ✅ Works via `accept-invite.js`
- Get invite info → ✅ Works via `get-invite-info.js`

---

## 💾 FINAL FUNCTION LIST (After Phase 1)

After deleting deprecated functions, you'll have **11 functions:**

1. ✅ `accept-invite.js` - Unified invite acceptance
2. ✅ `approve-update.js` - Update approval
3. ✅ `bestie-chat.js` - Bestie AI chat
4. ✅ `chat.js` - Wedding AI chat
5. ✅ `create-checkout.js` - Stripe checkout
6. ✅ `create-invite.js` - Unified invite creation
7. ✅ `create-wedding.js` - Wedding creation
8. ✅ `get-invite-info.js` - Invite validation
9. ✅ `get-my-bestie-permissions.js` - Get bestie permissions
10. ✅ `stripe-webhook.js` - Stripe webhooks
11. ✅ `update-my-inviter-access.js` - Update bestie permissions

**Status:** ✅ **UNDER 12-FUNCTION LIMIT** (with 1 function buffer)

---

## 📊 CONSOLIDATION SAVINGS SUMMARY

| Phase | Action | Functions Saved | New Count | Status |
|-------|--------|----------------|-----------|--------|
| **Current** | - | - | **14** | ❌ Over limit |
| **Phase 1** | Delete deprecated | **-3** | **11** | ✅ Compliant |
| **Phase 2** | Consolidate invites | **-2** | **9** | ✅ Safe buffer |
| **Phase 3** | Consolidate bestie perms | **-1** | **8** | ✅ Extra buffer |
| **Phase 4** | Consolidate chat | **-1** | **7** | ✅ Max buffer |

---

## 🚨 CRITICAL NOTES

### Must Keep Separate
- **`stripe-webhook.js`** - Must be separate endpoint for Stripe webhooks
  - Requires raw body parsing (`bodyParser: false`)
  - Cannot be consolidated with other functions
  - Vercel/Stripe require dedicated webhook URLs

### Safe to Consolidate
- **Invite operations** - All use same database tables and auth patterns
- **Bestie permissions** - Simple GET/POST split on same resource
- **Chat operations** - Same Claude API, just different contexts

### Frontend Impact
- Phase 1 (delete deprecated): **No impact** if already using unified system
- Phase 2 (consolidate invites): **Frontend changes required**
- Phase 3 (consolidate bestie perms): **Frontend changes required**
- Phase 4 (consolidate chat): **Frontend changes required**

---

## 📝 NEXT STEPS

1. **IMMEDIATE** - Run frontend search to confirm deprecated functions aren't used
2. **IMMEDIATE** - Delete 3 deprecated functions if safe
3. **SHORT TERM** - Implement Phase 2 (invite consolidation) for buffer
4. **LONG TERM** - Consider Phases 3-4 if more functions needed

---

**Audit Complete**
**Recommendation:** Execute Phase 1 immediately to get under the 12-function limit.

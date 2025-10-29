# Invite System Flow - Implementation Summary

This document describes the complete invite flow with the 3-role system (Owner, Partner, Bestie) and 1:1 bestie relationships.

## Complete Flow Diagram

```
Owner creates wedding
    ↓
    ├─→ "Invite Partner" button (generates link)
    │       ↓
    │   Partner clicks link → accept-invite-luxury.html
    │       ↓
    │   Shows: "Full view/edit access"
    │       ↓
    │   Creates account → Redirects to dashboard-luxury.html
    │       ↓
    │   Partner now sees "Invite Bestie" button
    │       ↓
    │   Partner invites Best Man → generates link
    │       ↓
    │   Best Man clicks link → accept-invite-luxury.html
    │       ↓
    │   Shows: "View access + Private bestie chat"
    │       ↓
    │   Creates account → Redirects to bestie-luxury.html
    │
    └─→ "Invite Bestie" button (generates link)
            ↓
        MOH clicks link → accept-invite-luxury.html
            ↓
        Shows: "View access + Private bestie chat"
            ↓
        Creates account → Redirects to bestie-luxury.html
```

## Role Structure

| Role | Created By | Max Count | Access Level | Dashboard | Invite Rights |
|------|-----------|-----------|--------------|-----------|---------------|
| **Owner** | Wedding creation | 1 per wedding | Full edit access | dashboard-luxury.html | Can invite 1 Partner + 1 Bestie |
| **Partner** | Owner invite | 1 per wedding | Full edit access | dashboard-luxury.html | Can invite 1 Bestie |
| **Bestie** | Owner/Partner invite | 2 per wedding (1 each) | View only | bestie-luxury.html | No invite rights |

## 1:1 Bestie Relationship

Each Owner and Partner can invite exactly **1 bestie**:
- **Owner** invites → MOH (Maid of Honor) - for bachelorette planning
- **Partner** invites → Best Man - for bachelor party planning

### Enforced Rules:
✅ Each person can only invite 1 bestie
✅ Each person can only have 1 pending bestie invite
✅ Max 2 besties total per wedding
✅ Each bestie is linked to their inviter via `invited_by_user_id`

## Permissions

### Owner & Partner
- ✅ **Full edit access** to wedding_profile
- ✅ Can manage vendors, budget, tasks
- ✅ Can update wedding details
- ✅ Can invite besties (1 each)
- ✅ Access to main Wedding Chat

### Bestie (MOH & Best Man)
- ✅ **View-only access** to wedding_profile
- ✅ Can see wedding date, location, preferences
- ✅ Private bestie planning chat (separate for each bestie)
- ✅ Can plan surprises without couple knowing
- ❌ Cannot edit wedding details
- ❌ Cannot invite others

## Accept Flow

### Partner Accept Flow
1. Clicks invite link → `accept-invite-luxury.html?token=partner_xxx`
2. Sees role badge: **"Wedding Partner"**
3. Sees permissions:
   - ✅ Can view and edit all wedding details
   - ✅ Can invite besties
4. Clicks "Accept Invitation"
5. Creates account (or signs in)
6. **Redirects to:** `dashboard-luxury.html?wedding_id={id}`
7. Sees full wedding dashboard with "Invite Bestie" button

### Bestie Accept Flow
1. Clicks invite link → `accept-invite-luxury.html?token=bestie_xxx`
2. Sees role badge: **"Bestie"**
3. Sees permissions:
   - ✅ Private bestie planning space
   - ✅ Can view wedding details
   - ✅ Limited editing access
4. Clicks "Accept Invitation"
5. Creates account (or signs in)
6. **Redirects to:** `bestie-luxury.html?wedding_id={id}`
7. Sees bestie dashboard with private planning chat

## Database Implementation

### invite_codes table
```sql
role TEXT CHECK (role IN ('partner', 'bestie'))
```
- Only partner and bestie can be invited (owner is created with wedding)

### wedding_members table
```sql
role TEXT CHECK (role IN ('owner', 'partner', 'bestie'))
invited_by_user_id UUID  -- Links bestie to their inviter
```

### Constraints
- `unique_partner_per_wedding`: Only 1 partner per wedding
- `check_bestie_limit`: Max 2 besties per wedding (enforced via trigger)

## API Validation

### create-invite.js
**Check 1:** Max 1 partner per wedding
```javascript
const hasPartner = existingMembers?.some(m => m.role === 'partner');
```

**Check 2:** Max 2 besties per wedding
```javascript
const bestieCount = existingMembers?.filter(m => m.role === 'bestie').length;
```

**Check 3:** Each person can only invite 1 bestie (NEW)
```javascript
const userAlreadyInvitedBestie = existingMembers?.some(
  m => m.role === 'bestie' && m.invited_by_user_id === user.id
);
```

**Check 4:** No duplicate pending invites (NEW)
```javascript
const pendingInvites = await supabaseAdmin
  .from('invite_codes')
  .select('id')
  .eq('created_by', user.id)
  .eq('role', 'bestie')
  .or('is_used.is.null,is_used.eq.false');
```

### accept-invite.js
**Redirect Logic:**
```javascript
redirect_to: intendedRole === 'bestie'
  ? `/bestie-luxury.html?wedding_id=${invite.wedding_id}`
  : `/dashboard-luxury.html?wedding_id=${invite.wedding_id}`
```

## Frontend Pages

### invite-luxury.html
- Accessible by: Owner and Partner
- Shows 2 buttons:
  - **"Invite Partner"** (disabled if partner exists)
  - **"Invite Bestie"** (disabled if user already invited a bestie)
- Displays active pending invites
- Shows current wedding members

### accept-invite-luxury.html
- Used for BOTH partner and bestie invites
- Dynamically shows role-specific information:
  - Partner: "Full Partner Access"
  - Bestie: "Bestie Access"
- Redirects based on role after acceptance

### dashboard-luxury.html
- For: Owner and Partner
- Full wedding planning access
- "Invite Bestie" button (if haven't invited one yet)

### bestie-luxury.html
- For: Besties (MOH & Best Man)
- Private planning chat
- View-only access to wedding details
- Can see preferences for planning surprises

## Testing Checklist

### Test 1: Owner Invites Partner
- [ ] Owner creates wedding
- [ ] Owner clicks "Invite Partner"
- [ ] Link generated successfully
- [ ] Partner accepts and gets full edit access
- [ ] Partner redirects to dashboard-luxury.html
- [ ] Partner sees "Invite Bestie" button
- [ ] "Invite Partner" button now disabled for Owner

### Test 2: Owner Invites Bestie (MOH)
- [ ] Owner clicks "Invite Bestie"
- [ ] Link generated successfully
- [ ] MOH accepts and gets view-only access
- [ ] MOH redirects to bestie-luxury.html
- [ ] MOH sees private planning chat
- [ ] Owner's "Invite Bestie" button now disabled
- [ ] Error if Owner tries to invite another bestie

### Test 3: Partner Invites Bestie (Best Man)
- [ ] Partner clicks "Invite Bestie"
- [ ] Link generated successfully
- [ ] Best Man accepts and gets view-only access
- [ ] Best Man redirects to bestie-luxury.html
- [ ] Best Man sees private planning chat (separate from MOH)
- [ ] Partner's "Invite Bestie" button now disabled
- [ ] Error if Partner tries to invite another bestie

### Test 4: Validation Checks
- [ ] Cannot invite 2nd partner (error shown)
- [ ] Cannot invite 3rd bestie (error shown)
- [ ] Owner cannot invite 2nd bestie after inviting 1st
- [ ] Partner cannot invite 2nd bestie after inviting 1st
- [ ] Cannot create duplicate pending bestie invite

### Test 5: Bestie Features
- [ ] Each bestie has separate private chat
- [ ] Besties can view wedding date, location, preferences
- [ ] Besties cannot edit wedding details
- [ ] Besties can plan surprises without couple knowing

## Error Messages

| Scenario | Error Message |
|----------|---------------|
| 2nd partner | "This wedding already has a partner. Only 1 partner allowed per wedding." |
| 3rd bestie | "This wedding already has 2 besties. Maximum 2 besties allowed per wedding." |
| 2nd bestie by same person | "You have already invited a bestie. Each person can only invite 1 bestie." |
| Duplicate pending invite | "You already have a pending bestie invite. Please wait for it to be accepted or delete it first." |

## Summary of Changes

### What's Implemented ✅
1. Clean 3-role system (Owner, Partner, Bestie)
2. 1:1 bestie relationship (each person invites 1)
3. Correct redirect flow (besties → bestie dashboard)
4. View-only access for besties
5. Private planning chat for each bestie
6. Validation for all limits and constraints
7. Clear error messages
8. Separate dashboards for different roles

### What's Already There ✅
- accept-invite-luxury.html (works for both partner and bestie)
- bestie-luxury.html (bestie dashboard)
- invite-luxury.html (invite management)
- All database constraints and RLS policies

### Ready to Test ✅
The system is now fully implemented and ready for testing. Follow the testing checklist above to verify all flows work correctly.

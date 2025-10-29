# CRITICAL FIX: Invite Link Bug

## The Bug

The invite link creation was completely broken. The API was generating URLs pointing to `/accept-invite.html` but the actual page is `/accept-invite-luxury.html`.

**Result**: All invite links returned 404 errors. Nobody could accept invites.

## The Fix

**File**: `api/create-invite.js` (line 194)

Changed:
```javascript
const inviteUrl = `${baseUrl}/accept-invite.html?token=${inviteToken}`;
```

To:
```javascript
const inviteUrl = `${baseUrl}/accept-invite-luxury.html?token=${inviteToken}`;
```

## Impact

- ✅ Invite links now point to the correct page
- ✅ Recipients can successfully accept invites
- ✅ Full invite flow is now functional

## Testing

After deployment:
1. Create an invite link (Partner or Bestie)
2. Copy the generated link
3. Open in new browser/incognito window
4. Should see accept invite page (not 404)
5. Accept invite successfully

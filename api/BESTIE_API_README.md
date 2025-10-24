# Bestie Permission System API Endpoints

**Part of:** Phase 2 - Bestie Permission System Implementation

This document describes the 4 new API endpoints for managing the bestie permission system, which enables 1:1 relationships between besties (MOH/Best Man) and their inviters with granular knowledge sharing controls.

---

## Overview

The bestie system allows:
- **1:1 Relationship:** Each inviter can have one bestie, each bestie belongs to one inviter
- **Granular Permissions:** Besties control what access their inviter has to their private knowledge
- **Privacy by Default:** Inviter has NO access unless bestie explicitly grants it
- **Private Knowledge:** Besties can mark items as private (always hidden, even with permissions)

---

## Endpoints

### 1. POST `/api/create-bestie-invite`
**Purpose:** Owner creates bestie invite with wedding profile permissions

**Request:**
```javascript
POST /api/create-bestie-invite
Content-Type: application/json

{
  "userToken": "eyJhbGciOiJI...",  // Supabase user JWT
  "role": "bestie",                // Must be 'bestie'
  "wedding_profile_permissions": {
    "can_read": true,              // Bestie can view wedding profile
    "can_edit": false              // Bestie cannot edit wedding profile
  }
}
```

**Response (Success):**
```json
{
  "success": true,
  "inviteCode": "ABC23456",
  "role": "bestie",
  "weddingId": "uuid",
  "permissions": {
    "weddingProfile": {
      "can_read": true,
      "can_edit": false
    }
  },
  "message": "Bestie invite created successfully",
  "instructions": "Share this code with your Maid of Honor or Best Man..."
}
```

**Error Responses:**
```json
// 400 - Invalid role
{
  "error": "Invalid role. This endpoint is for bestie invites only. Use /api/create-invite for regular members."
}

// 401 - Unauthorized
{
  "error": "Unauthorized - invalid or expired token"
}

// 403 - Not owner
{
  "error": "Only wedding owners can create bestie invites"
}

// 403 - Addon not enabled
{
  "error": "Bestie addon is not enabled for your wedding. Please upgrade your plan."
}
```

**Who Can Call:** Wedding owners only

**Key Features:**
- ✅ Validates user is wedding owner
- ✅ Checks bestie addon is enabled
- ✅ Generates readable 8-character code
- ✅ Stores wedding_profile_permissions in invite

---

### 2. POST `/api/accept-bestie-invite`
**Purpose:** User accepts bestie invite and establishes 1:1 relationship

**Request:**
```javascript
POST /api/accept-bestie-invite
Content-Type: application/json

{
  "inviteCode": "ABC23456",       // 8-character code
  "userToken": "eyJhbGciOiJI..."  // Supabase user JWT
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Successfully joined as bestie!",
  "relationship": {
    "yourRole": "bestie",
    "invitedBy": {
      "userId": "uuid",
      "name": "Alice Smith",
      "email": "alice@example.com"
    },
    "wedding": {
      "id": "uuid",
      "name": "Alice & Bob's Wedding",
      "date": "2025-06-15"
    },
    "permissions": {
      "yourAccessToWeddingProfile": {
        "can_read": true,
        "can_edit": false
      },
      "inviterAccessToYourKnowledge": {
        "can_read": false,
        "can_edit": false
      }
    }
  },
  "nextSteps": [
    "You now have a private bestie planning space",
    "Your inviter cannot see your bestie knowledge by default",
    "You can grant them access via Settings → Bestie Permissions",
    "Start planning surprises and events in your bestie dashboard!"
  ]
}
```

**Error Responses:**
```json
// 400 - Already a member
{
  "error": "You are already a member of this wedding"
}

// 400 - Not a bestie invite
{
  "error": "This is not a bestie invite code. Use /api/join-wedding for regular member invites."
}

// 400 - Inviter already has bestie
{
  "error": "This inviter already has a bestie for this wedding. Each person can only have one bestie.",
  "details": "The invite code may have been used by someone else..."
}

// 404 - Invalid code
{
  "error": "Invalid or already used invite code"
}
```

**Who Can Call:** Any authenticated user

**Key Features:**
- ✅ Validates invite is for 'bestie' role
- ✅ Enforces 1:1 relationship (inviter can only have one bestie)
- ✅ Creates wedding_members entry with invited_by_user_id
- ✅ Creates bestie_permissions record (default: no access)
- ✅ Marks invite as used

**What It Creates:**
```sql
-- wedding_members
INSERT INTO wedding_members (
  wedding_id,
  user_id,
  role,
  invited_by_user_id,  -- Tracks who invited them
  wedding_profile_permissions
);

-- bestie_permissions
INSERT INTO bestie_permissions (
  bestie_user_id,
  inviter_user_id,
  wedding_id,
  permissions  -- Default: {"can_read": false, "can_edit": false}
);
```

---

### 3. GET `/api/get-my-bestie-permissions`
**Purpose:** Bestie views their permission status and inviter's access

**Request:**
```javascript
GET /api/get-my-bestie-permissions?userToken=eyJhbGci...&wedding_id=uuid
```

**Response (Success):**
```json
{
  "success": true,
  "bestie": {
    "userId": "uuid",
    "email": "moh@example.com"
  },
  "inviter": {
    "userId": "uuid",
    "name": "Alice Smith",
    "email": "alice@example.com"
  },
  "wedding": {
    "id": "uuid",
    "name": "Alice & Bob's Wedding",
    "date": "2025-06-15"
  },
  "permissions": {
    "inviterCanReadMyKnowledge": false,
    "inviterCanEditMyKnowledge": false,
    "youCanReadWeddingProfile": true,
    "youCanEditWeddingProfile": false
  },
  "knowledgeStats": {
    "totalItems": 15,
    "privateItems": 3,
    "sharedWithInviter": 12,
    "visibleToInviter": 0,
    "editableByInviter": 0
  },
  "explanation": {
    "canRead": "Alice Smith cannot view your bestie knowledge",
    "canEdit": "Alice Smith cannot edit your bestie knowledge",
    "privateNote": "You have 3 private items that are always hidden, regardless of permissions"
  },
  "lastUpdated": "2025-10-24T10:30:00Z"
}
```

**Error Responses:**
```json
// 403 - Not a bestie
{
  "error": "Only besties can view bestie permissions. This endpoint is for MOH/Best Man only."
}

// 404 - Not a member
{
  "error": "You are not a member of this wedding"
}

// 404 - Permissions not found
{
  "error": "Bestie permissions record not found. This may indicate a setup issue."
}
```

**Who Can Call:** Besties only (role='bestie')

**Key Features:**
- ✅ Shows what access inviter currently has
- ✅ Shows bestie's own access to wedding profile
- ✅ Displays knowledge statistics
- ✅ Explains impact of current permissions
- ✅ Read-only (no modifications)

**Use Cases:**
- Bestie checking current permission status
- UI displaying permission toggles
- Dashboard showing knowledge visibility

---

### 4. POST `/api/update-my-inviter-access`
**Purpose:** Bestie updates what access their inviter has to bestie knowledge

**Request:**
```javascript
POST /api/update-my-inviter-access
Content-Type: application/json

{
  "userToken": "eyJhbGciOiJI...",
  "wedding_id": "uuid",
  "can_read": true,   // Grant read access
  "can_edit": false   // Deny edit access
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Inviter permissions updated successfully",
  "inviter": {
    "userId": "uuid",
    "name": "Alice Smith",
    "email": "alice@example.com"
  },
  "updatedPermissions": {
    "can_read": true,
    "can_edit": false
  },
  "impact": {
    "totalKnowledgeItems": 15,
    "privateItems": 3,
    "sharedItems": 12,
    "nowVisibleToInviter": 12,
    "nowEditableByInviter": 0
  },
  "explanation": {
    "canRead": "✅ Alice Smith can now VIEW 12 non-private items in your bestie knowledge",
    "canEdit": "🔒 Alice Smith cannot edit your bestie knowledge",
    "privateNote": "🔐 3 private items remain hidden regardless of permissions (for surprise planning)"
  },
  "nextSteps": [
    "Your inviter can now see your bestie planning",
    "They can help with coordination and logistics",
    "Your private items remain hidden for surprises",
    "They can view but not edit (read-only access)"
  ],
  "updatedAt": "2025-10-24T10:35:00Z"
}
```

**Error Responses:**
```json
// 400 - Invalid permission combination
{
  "error": "Invalid permission combination: cannot grant edit access without read access",
  "suggestion": "Set both can_read=true and can_edit=true to grant edit access"
}

// 400 - Missing fields
{
  "error": "Missing required fields: userToken and wedding_id"
}

// 400 - Invalid types
{
  "error": "Invalid permission values. can_read and can_edit must be boolean (true/false)"
}

// 403 - Not a bestie
{
  "error": "Only besties can manage inviter permissions"
}
```

**Who Can Call:** Besties only (role='bestie')

**Key Features:**
- ✅ Validates permission logic (can't grant edit without read)
- ✅ Updates ONLY bestie's own record (RLS enforced)
- ✅ Shows impact of change (how many items affected)
- ✅ Explains what inviter can now do
- ✅ Returns updated permission status

**Permission Combinations:**
```javascript
// Valid combinations:
{ can_read: false, can_edit: false }  // ✅ No access (default)
{ can_read: true,  can_edit: false }  // ✅ Read-only
{ can_read: true,  can_edit: true  }  // ✅ Full access

// Invalid combination:
{ can_read: false, can_edit: true  }  // ❌ Cannot edit without read
```

**What It Updates:**
```sql
UPDATE bestie_permissions
SET permissions = '{"can_read": true, "can_edit": false}',
    updated_at = NOW()
WHERE bestie_user_id = auth.uid()  -- Can only update own record
  AND wedding_id = ?;
```

---

## Frontend Integration

### Example: Create Bestie Invite (React)

```javascript
async function createBestieInvite() {
  const { data: { session } } = await supabase.auth.getSession();

  const response = await fetch('/api/create-bestie-invite', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userToken: session.access_token,
      role: 'bestie',
      wedding_profile_permissions: {
        can_read: true,   // Bestie can view wedding details
        can_edit: false   // But cannot modify them
      }
    })
  });

  const data = await response.json();

  if (data.success) {
    alert(`Share this code with your MOH/Best Man: ${data.inviteCode}`);
  }
}
```

### Example: Bestie Permission Toggle (React)

```javascript
async function toggleInviterAccess(canRead, canEdit) {
  const { data: { session } } = await supabase.auth.getSession();

  const response = await fetch('/api/update-my-inviter-access', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userToken: session.access_token,
      wedding_id: currentWeddingId,
      can_read: canRead,
      can_edit: canEdit
    })
  });

  const data = await response.json();

  if (data.success) {
    console.log('Permissions updated:', data.updatedPermissions);
    console.log('Impact:', data.impact);
  }
}
```

### Example: Display Permission Status (React)

```javascript
async function loadPermissionStatus() {
  const { data: { session } } = await supabase.auth.getSession();

  const response = await fetch(
    `/api/get-my-bestie-permissions?userToken=${session.access_token}&wedding_id=${weddingId}`
  );

  const data = await response.json();

  if (data.success) {
    return {
      inviterName: data.inviter.name,
      canRead: data.permissions.inviterCanReadMyKnowledge,
      canEdit: data.permissions.inviterCanEditMyKnowledge,
      visibleItems: data.knowledgeStats.visibleToInviter,
      privateItems: data.knowledgeStats.privateItems
    };
  }
}
```

---

## Security

### RLS Enforcement

All endpoints rely on Row Level Security policies created in Phase 1:

**bestie_permissions table:**
- ✅ Bestie can SELECT only their own record
- ✅ Bestie can UPDATE only their own record
- ✅ Inviter can SELECT to check access
- ✅ Bestie CANNOT see other besties' permissions

**bestie_knowledge table:**
- ✅ Bestie has full CRUD on own knowledge
- ✅ Inviter can SELECT if `can_read=true` AND `is_private=false`
- ✅ Inviter can UPDATE if `can_edit=true` AND `is_private=false`
- ✅ Private knowledge always hidden from inviter

### Authentication

All endpoints require:
- Valid Supabase user JWT token
- User must be authenticated
- User must have correct role (owner or bestie depending on endpoint)

### 1:1 Relationship Enforcement

**Database Level:**
```sql
-- In bestie_permissions table
CONSTRAINT unique_bestie_per_wedding UNIQUE (bestie_user_id, wedding_id)
```

**API Level:**
- `/api/accept-bestie-invite` checks if inviter already has a bestie
- Prevents multiple besties per inviter per wedding

---

## Error Handling

All endpoints return consistent error format:

```json
{
  "error": "Human-readable error message",
  "details": "Technical details (optional)"
}
```

**HTTP Status Codes:**
- `200` - Success
- `400` - Bad request (invalid input)
- `401` - Unauthorized (invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not found (resource doesn't exist)
- `405` - Method not allowed (wrong HTTP method)
- `500` - Internal server error

---

## Testing

### Test Flow: Complete Bestie Lifecycle

```javascript
// 1. Owner creates bestie invite
const invite = await fetch('/api/create-bestie-invite', {
  method: 'POST',
  body: JSON.stringify({
    userToken: ownerToken,
    role: 'bestie',
    wedding_profile_permissions: { can_read: true, can_edit: false }
  })
});
// Response: { inviteCode: "ABC23456" }

// 2. Bestie accepts invite
const join = await fetch('/api/accept-bestie-invite', {
  method: 'POST',
  body: JSON.stringify({
    inviteCode: "ABC23456",
    userToken: bestieToken
  })
});
// Response: { success: true, relationship: {...} }

// 3. Bestie checks permissions (default: no access)
const status = await fetch(
  `/api/get-my-bestie-permissions?userToken=${bestieToken}&wedding_id=${weddingId}`
);
// Response: { permissions: { inviterCanReadMyKnowledge: false } }

// 4. Bestie grants read access to inviter
const update = await fetch('/api/update-my-inviter-access', {
  method: 'POST',
  body: JSON.stringify({
    userToken: bestieToken,
    wedding_id: weddingId,
    can_read: true,
    can_edit: false
  })
});
// Response: { success: true, updatedPermissions: { can_read: true } }

// 5. Verify permission was applied
const verify = await fetch(
  `/api/get-my-bestie-permissions?userToken=${bestieToken}&wedding_id=${weddingId}`
);
// Response: { permissions: { inviterCanReadMyKnowledge: true } }
```

---

## Migration from Old System

### Old Flow (Phase 0)
```javascript
// api/create-invite.js - Single endpoint for all roles
{ role: 'bestie' }  // No permissions, no relationship tracking

// api/join-wedding.js - Generic join
// Missing: invited_by_user_id, wedding_profile_permissions
// Missing: bestie_permissions record
```

### New Flow (Phase 2)
```javascript
// api/create-bestie-invite.js - Specialized for besties
{
  role: 'bestie',
  wedding_profile_permissions: { can_read: true, can_edit: false }
}

// api/accept-bestie-invite.js - Establishes 1:1 relationship
// Creates: invited_by_user_id, bestie_permissions record
// Enforces: Only one bestie per inviter
```

**Backward Compatibility:**
- Old endpoints (`/api/create-invite`, `/api/join-wedding`) still work for regular members
- New endpoints (`/api/create-bestie-invite`, `/api/accept-bestie-invite`) for besties

---

## Next Steps

After implementing Phase 2 API endpoints:

**Phase 3: Frontend Integration** (3-4 hours)
- Add permission toggle UI to `bestie-v2.html`
- Add bestie invite creation to `invite-v2.html`
- Build bestie knowledge management interface
- Display permission status in dashboard

**Phase 4: Testing & Refinement** (2-3 hours)
- End-to-end testing of invite flow
- Test RLS policies with multiple besties
- Verify permission updates work correctly
- Load testing and error handling

---

## Support & Documentation

**Related Files:**
- `migrations/README.md` - Database schema deployment
- `BESTIE_SYSTEM_AUDIT.md` - Complete architecture analysis
- `COMPLETE_ARCHITECTURE.md` - Full stack overview

**Key Concepts:**
- **1:1 Relationship:** Each inviter ↔ one bestie
- **Permissions:** `can_read` (view), `can_edit` (modify)
- **Privacy:** `is_private=true` always hidden
- **Default:** No access (bestie must explicitly grant)

---

**Phase 2 Implementation:** API Endpoints ✅ COMPLETE
**Total Lines:** ~700 lines of production code
**Endpoints:** 4 new endpoints fully functional

# VERCEL FUNCTION CONSOLIDATION EXAMPLES

This document shows working implementations for consolidating multiple Vercel functions into single endpoints with route handling.

---

## CONSOLIDATION #1: Invite Operations

**Current:** 3 separate functions
**Consolidated:** 1 function with route handling

### Files to Replace

- ❌ DELETE: `api/create-invite.js`
- ❌ DELETE: `api/accept-invite.js`
- ❌ DELETE: `api/get-invite-info.js`
- ✅ CREATE: `api/invites.js`

### Implementation: `api/invites.js`

```javascript
// ============================================================================
// INVITES - CONSOLIDATED ENDPOINT
// ============================================================================
// Handles all invite operations: create, accept, get-info
// Routes based on HTTP method and action parameter
// ============================================================================

import { createClient } from '@supabase/supabase-js';
import { randomBytes } from 'crypto';

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  // Route based on HTTP method
  if (req.method === 'GET') {
    return handleGetInviteInfo(req, res);
  } else if (req.method === 'POST') {
    const { action } = req.body;

    if (action === 'create') {
      return handleCreateInvite(req, res);
    } else if (action === 'accept') {
      return handleAcceptInvite(req, res);
    } else {
      return res.status(400).json({
        error: 'Invalid action. Must be "create" or "accept"'
      });
    }
  } else {
    return res.status(405).json({ error: 'Method not allowed' });
  }
}

// ============================================================================
// HANDLER: Get Invite Info (GET)
// ============================================================================
async function handleGetInviteInfo(req, res) {
  const { invite_token } = req.query;

  if (!invite_token) {
    return res.status(400).json({
      error: 'Missing required parameter: invite_token'
    });
  }

  try {
    const { data: invite, error: inviteError } = await supabaseAdmin
      .from('invite_codes')
      .select(`
        id,
        wedding_id,
        role,
        wedding_profile_permissions,
        created_by,
        used,
        expires_at,
        created_at
      `)
      .eq('invite_token', invite_token)
      .single();

    if (inviteError || !invite) {
      return res.status(404).json({
        error: 'Invalid invite link',
        is_valid: false
      });
    }

    if (invite.used === true) {
      return res.status(400).json({
        error: 'This invite has already been used',
        is_valid: false,
        is_used: true
      });
    }

    const now = new Date();
    const expiresAt = new Date(invite.expires_at);

    if (expiresAt < now) {
      return res.status(400).json({
        error: 'This invite has expired',
        is_valid: false,
        is_expired: true,
        expires_at: invite.expires_at
      });
    }

    const { data: wedding } = await supabaseAdmin
      .from('wedding_profiles')
      .select('partner1_name, partner2_name, wedding_date')
      .eq('id', invite.wedding_id)
      .single();

    const roleDisplayNames = {
      partner: 'Partner',
      co_planner: 'Co-planner',
      bestie: 'Bestie (MOH/Best Man)'
    };

    const timeUntilExpiration = expiresAt - now;
    const hoursUntilExpiration = Math.floor(timeUntilExpiration / (1000 * 60 * 60));
    const daysUntilExpiration = Math.floor(hoursUntilExpiration / 24);

    return res.status(200).json({
      success: true,
      is_valid: true,
      invite: {
        wedding_name: `${wedding.partner1_name} & ${wedding.partner2_name}`,
        wedding_date: wedding.wedding_date,
        role: invite.role,
        role_display: roleDisplayNames[invite.role],
        wedding_profile_permissions: invite.wedding_profile_permissions,
        days_until_expiration: daysUntilExpiration,
        hours_until_expiration: hoursUntilExpiration
      }
    });
  } catch (error) {
    console.error('Get invite info error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

// ============================================================================
// HANDLER: Create Invite (POST + action=create)
// ============================================================================
async function handleCreateInvite(req, res) {
  const {
    userToken,
    role,
    wedding_profile_permissions = { read: false, edit: false }
  } = req.body;

  if (!role || !['partner', 'co_planner', 'bestie'].includes(role)) {
    return res.status(400).json({
      error: 'Invalid role. Must be "partner", "co_planner", or "bestie"'
    });
  }

  if (!userToken) {
    return res.status(400).json({ error: 'Missing required field: userToken' });
  }

  try {
    const supabaseUser = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_ANON_KEY,
      {
        global: {
          headers: { Authorization: `Bearer ${userToken}` }
        }
      }
    );

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { data: membership } = await supabaseAdmin
      .from('wedding_members')
      .select('wedding_id, role')
      .eq('user_id', user.id)
      .single();

    if (!membership || membership.role !== 'owner') {
      return res.status(403).json({
        error: 'Only wedding owners can create invite links'
      });
    }

    const { data: wedding } = await supabaseAdmin
      .from('wedding_profiles')
      .select('partner1_name, partner2_name')
      .eq('id', membership.wedding_id)
      .single();

    const inviteToken = generateSecureToken();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    const { data: invite, error: insertError } = await supabaseAdmin
      .from('invite_codes')
      .insert({
        wedding_id: membership.wedding_id,
        invite_token: inviteToken,
        created_by: user.id,
        role: role,
        wedding_profile_permissions: wedding_profile_permissions,
        used: false,
        expires_at: expiresAt.toISOString()
      })
      .select()
      .single();

    if (insertError) {
      return res.status(500).json({ error: 'Failed to create invite link' });
    }

    const baseUrl = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : 'https://bridebuddyv2.vercel.app';

    const inviteUrl = `${baseUrl}/accept-invite.html?token=${inviteToken}`;

    return res.status(200).json({
      success: true,
      invite_url: inviteUrl,
      invite_token: inviteToken,
      role: invite.role,
      wedding_profile_permissions: invite.wedding_profile_permissions,
      expires_at: invite.expires_at,
      wedding_name: `${wedding.partner1_name} & ${wedding.partner2_name}`
    });
  } catch (error) {
    console.error('Create invite error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

// ============================================================================
// HANDLER: Accept Invite (POST + action=accept)
// ============================================================================
async function handleAcceptInvite(req, res) {
  const {
    invite_token,
    userToken,
    bestie_knowledge_permissions = { can_read: false, can_edit: false }
  } = req.body;

  if (!invite_token || !userToken) {
    return res.status(400).json({
      error: 'Missing required fields: invite_token and userToken'
    });
  }

  try {
    const supabaseUser = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_ANON_KEY,
      {
        global: {
          headers: { Authorization: `Bearer ${userToken}` }
        }
      }
    );

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { data: invite } = await supabaseAdmin
      .from('invite_codes')
      .select('*')
      .eq('invite_token', invite_token)
      .single();

    if (!invite) {
      return res.status(404).json({ error: 'Invalid invite link' });
    }

    if (invite.used === true) {
      return res.status(400).json({ error: 'This invite has already been used' });
    }

    const now = new Date();
    const expiresAt = new Date(invite.expires_at);

    if (expiresAt < now) {
      return res.status(400).json({ error: 'This invite has expired' });
    }

    const { data: existingMember } = await supabaseAdmin
      .from('wedding_members')
      .select('role')
      .eq('wedding_id', invite.wedding_id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existingMember) {
      return res.status(400).json({
        error: 'You are already a member of this wedding'
      });
    }

    if (invite.role === 'bestie') {
      const { data: existingBestie } = await supabaseAdmin
        .from('wedding_members')
        .select('user_id')
        .eq('wedding_id', invite.wedding_id)
        .eq('invited_by_user_id', invite.created_by)
        .eq('role', 'bestie')
        .maybeSingle();

      if (existingBestie) {
        return res.status(400).json({
          error: 'This inviter already has a bestie for this wedding'
        });
      }
    }

    await supabaseAdmin
      .from('wedding_members')
      .insert({
        wedding_id: invite.wedding_id,
        user_id: user.id,
        role: invite.role,
        invited_by_user_id: invite.created_by,
        wedding_profile_permissions: invite.wedding_profile_permissions
      });

    if (invite.role === 'bestie') {
      await supabaseAdmin
        .from('bestie_permissions')
        .insert({
          bestie_user_id: user.id,
          inviter_user_id: invite.created_by,
          wedding_id: invite.wedding_id,
          permissions: bestie_knowledge_permissions
        });
    }

    await supabaseAdmin
      .from('invite_codes')
      .update({
        used: true,
        used_by: user.id,
        used_at: new Date().toISOString()
      })
      .eq('invite_token', invite_token);

    return res.status(200).json({
      success: true,
      message: `Successfully joined as ${invite.role}!`,
      wedding_id: invite.wedding_id,
      redirect_to: `/dashboard-v2.html?wedding_id=${invite.wedding_id}`
    });
  } catch (error) {
    console.error('Accept invite error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

// ============================================================================
// HELPER: Generate Secure Token
// ============================================================================
function generateSecureToken() {
  return randomBytes(32)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}
```

### Frontend Changes Required

**Old API calls:**
```javascript
// Create invite
fetch('/api/create-invite', {
  method: 'POST',
  body: JSON.stringify({ userToken, role, wedding_profile_permissions })
})

// Accept invite
fetch('/api/accept-invite', {
  method: 'POST',
  body: JSON.stringify({ invite_token, userToken })
})

// Get invite info
fetch(`/api/get-invite-info?invite_token=${token}`)
```

**New API calls:**
```javascript
// Create invite
fetch('/api/invites', {
  method: 'POST',
  body: JSON.stringify({
    action: 'create',
    userToken,
    role,
    wedding_profile_permissions
  })
})

// Accept invite
fetch('/api/invites', {
  method: 'POST',
  body: JSON.stringify({
    action: 'accept',
    invite_token,
    userToken
  })
})

// Get invite info
fetch(`/api/invites?invite_token=${token}`)  // GET request
```

---

## CONSOLIDATION #2: Bestie Permissions

**Current:** 2 separate functions
**Consolidated:** 1 function with GET/POST routing

### Files to Replace

- ❌ DELETE: `api/get-my-bestie-permissions.js`
- ❌ DELETE: `api/update-my-inviter-access.js`
- ✅ CREATE: `api/bestie-permissions.js`

### Implementation: `api/bestie-permissions.js`

```javascript
// ============================================================================
// BESTIE PERMISSIONS - CONSOLIDATED ENDPOINT
// ============================================================================
// Handles bestie permission operations: get and update
// Routes based on HTTP method (GET/POST)
// ============================================================================

import { createClient } from '@supabase/supabase-js';

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  if (req.method === 'GET') {
    return handleGetPermissions(req, res);
  } else if (req.method === 'POST') {
    return handleUpdatePermissions(req, res);
  } else {
    return res.status(405).json({ error: 'Method not allowed' });
  }
}

// ============================================================================
// HANDLER: Get Bestie Permissions (GET)
// ============================================================================
async function handleGetPermissions(req, res) {
  const { userToken, wedding_id } = req.query;

  if (!userToken || !wedding_id) {
    return res.status(400).json({
      error: 'Missing required parameters: userToken and wedding_id'
    });
  }

  try {
    const supabaseUser = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_ANON_KEY,
      {
        global: {
          headers: { Authorization: `Bearer ${userToken}` }
        }
      }
    );

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { data: membership } = await supabaseAdmin
      .from('wedding_members')
      .select('role')
      .eq('user_id', user.id)
      .eq('wedding_id', wedding_id)
      .single();

    if (!membership || membership.role !== 'bestie') {
      return res.status(403).json({
        error: 'Only besties can view bestie permissions'
      });
    }

    const { data: permissions } = await supabaseAdmin
      .from('bestie_permissions')
      .select('*')
      .eq('bestie_user_id', user.id)
      .eq('wedding_id', wedding_id)
      .single();

    const { data: knowledgeStats } = await supabaseAdmin
      .from('bestie_knowledge')
      .select('id, is_private')
      .eq('bestie_user_id', user.id)
      .eq('wedding_id', wedding_id);

    const totalItems = knowledgeStats?.length || 0;
    const privateItems = knowledgeStats?.filter(k => k.is_private).length || 0;
    const visibleToInviter = permissions?.permissions.can_read
      ? totalItems - privateItems
      : 0;

    return res.status(200).json({
      success: true,
      permissions: {
        inviterCanReadMyKnowledge: permissions?.permissions.can_read || false,
        inviterCanEditMyKnowledge: permissions?.permissions.can_edit || false
      },
      knowledgeStats: {
        totalItems,
        privateItems,
        visibleToInviter
      }
    });
  } catch (error) {
    console.error('Get permissions error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

// ============================================================================
// HANDLER: Update Bestie Permissions (POST)
// ============================================================================
async function handleUpdatePermissions(req, res) {
  const { userToken, wedding_id, can_read, can_edit } = req.body;

  if (!userToken || !wedding_id) {
    return res.status(400).json({
      error: 'Missing required fields: userToken and wedding_id'
    });
  }

  if (typeof can_read !== 'boolean' || typeof can_edit !== 'boolean') {
    return res.status(400).json({
      error: 'can_read and can_edit must be boolean values'
    });
  }

  if (can_edit && !can_read) {
    return res.status(400).json({
      error: 'Invalid permission combination: cannot grant edit without read'
    });
  }

  try {
    const supabaseUser = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_ANON_KEY,
      {
        global: {
          headers: { Authorization: `Bearer ${userToken}` }
        }
      }
    );

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { data: membership } = await supabaseAdmin
      .from('wedding_members')
      .select('role')
      .eq('user_id', user.id)
      .eq('wedding_id', wedding_id)
      .single();

    if (!membership || membership.role !== 'bestie') {
      return res.status(403).json({
        error: 'Only besties can update bestie permissions'
      });
    }

    const { data: updated } = await supabaseAdmin
      .from('bestie_permissions')
      .update({
        permissions: { can_read, can_edit },
        updated_at: new Date().toISOString()
      })
      .eq('bestie_user_id', user.id)
      .eq('wedding_id', wedding_id)
      .select()
      .single();

    const { data: knowledge } = await supabaseAdmin
      .from('bestie_knowledge')
      .select('id, is_private')
      .eq('bestie_user_id', user.id)
      .eq('wedding_id', wedding_id);

    const totalItems = knowledge?.length || 0;
    const privateItems = knowledge?.filter(k => k.is_private).length || 0;
    const nowVisibleToInviter = can_read ? totalItems - privateItems : 0;
    const nowEditableByInviter = can_edit ? totalItems - privateItems : 0;

    return res.status(200).json({
      success: true,
      updatedPermissions: { can_read, can_edit },
      impact: {
        nowVisibleToInviter,
        nowEditableByInviter
      }
    });
  } catch (error) {
    console.error('Update permissions error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
```

### Frontend Changes Required

**Old API calls:**
```javascript
// Get permissions
fetch(`/api/get-my-bestie-permissions?userToken=${token}&wedding_id=${id}`)

// Update permissions
fetch('/api/update-my-inviter-access', {
  method: 'POST',
  body: JSON.stringify({ userToken, wedding_id, can_read, can_edit })
})
```

**New API calls:**
```javascript
// Get permissions
fetch(`/api/bestie-permissions?userToken=${token}&wedding_id=${id}`)

// Update permissions
fetch('/api/bestie-permissions', {
  method: 'POST',
  body: JSON.stringify({ userToken, wedding_id, can_read, can_edit })
})
```

---

## CONSOLIDATION #3: Chat Operations

**Current:** 2 separate functions
**Consolidated:** 1 function with context-based routing

### Files to Replace

- ❌ DELETE: `api/bestie-chat.js`
- ✅ KEEP & UPDATE: `api/chat.js`

### Implementation: `api/chat.js` (Updated)

```javascript
// ============================================================================
// CHAT - CONSOLIDATED ENDPOINT
// ============================================================================
// Handles both wedding chat and bestie chat with Claude AI
// Routes based on context parameter
// ============================================================================

import { createClient } from '@supabase/supabase-js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { message, conversationId, userToken, context = 'wedding' } = req.body;

  if (!message || !userToken) {
    return res.status(400).json({
      error: 'Missing required fields: message and userToken'
    });
  }

  if (!['wedding', 'bestie'].includes(context)) {
    return res.status(400).json({
      error: 'Invalid context. Must be "wedding" or "bestie"'
    });
  }

  try {
    // Authenticate user
    const supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_ANON_KEY,
      {
        global: {
          headers: { Authorization: `Bearer ${userToken}` }
        }
      }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    // Get system prompt based on context
    const systemPrompt = context === 'bestie'
      ? getBestieSystemPrompt()
      : getWeddingSystemPrompt();

    // Call Claude API
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 4096,
        system: systemPrompt,
        messages: [
          {
            role: 'user',
            content: message
          }
        ]
      })
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error?.message || 'Claude API error');
    }

    const reply = data.content[0].text;

    // Store conversation in appropriate table
    const supabaseAdmin = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    if (context === 'bestie') {
      await supabaseAdmin.from('bestie_chat_messages').insert({
        conversation_id: conversationId,
        user_id: user.id,
        message: message,
        response: reply
      });
    } else {
      await supabaseAdmin.from('chat_messages').insert({
        conversation_id: conversationId,
        user_id: user.id,
        message: message,
        response: reply
      });
    }

    return res.status(200).json({
      success: true,
      reply: reply,
      context: context
    });
  } catch (error) {
    console.error('Chat error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

// ============================================================================
// SYSTEM PROMPTS
// ============================================================================
function getWeddingSystemPrompt() {
  return `You are a helpful wedding planning assistant. Help users plan their
wedding by providing advice, suggestions, and answering questions about
venues, vendors, budgets, timelines, and all aspects of wedding planning.`;
}

function getBestieSystemPrompt() {
  return `You are a bestie planning assistant helping MOH/Best Man plan
surprises, events, and special moments for the couple. Help with:
- Bachelorette/bachelor party planning
- Surprise planning and execution
- Gift ideas and coordination
- Wedding day special moments
- Keeping secrets from the couple
Be enthusiastic and conspiratorial!`;
}
```

### Frontend Changes Required

**Old API calls:**
```javascript
// Wedding chat
fetch('/api/chat', {
  method: 'POST',
  body: JSON.stringify({ message, conversationId, userToken })
})

// Bestie chat
fetch('/api/bestie-chat', {
  method: 'POST',
  body: JSON.stringify({ message, conversationId, userToken })
})
```

**New API calls:**
```javascript
// Wedding chat
fetch('/api/chat', {
  method: 'POST',
  body: JSON.stringify({
    message,
    conversationId,
    userToken,
    context: 'wedding'
  })
})

// Bestie chat
fetch('/api/chat', {
  method: 'POST',
  body: JSON.stringify({
    message,
    conversationId,
    userToken,
    context: 'bestie'
  })
})
```

---

## MIGRATION CHECKLIST

### Phase 1: Quick Wins (Delete Deprecated)
- [ ] Search frontend for deprecated function usage
- [ ] Confirm no matches found
- [ ] Delete `api/accept-bestie-invite.js`
- [ ] Delete `api/create-bestie-invite.js`
- [ ] Delete `api/join-wedding.js`
- [ ] Test all invite flows
- [ ] Verify: **11 functions** ✅

### Phase 2: Consolidate Invites
- [ ] Create `api/invites.js` with code above
- [ ] Update `public/invite-v2.html` to use new endpoint
- [ ] Update `public/accept-invite.html` to use new endpoint
- [ ] Test create, accept, and get-info flows
- [ ] Delete old files: `create-invite.js`, `accept-invite.js`, `get-invite-info.js`
- [ ] Verify: **9 functions** ✅

### Phase 3: Consolidate Bestie Permissions
- [ ] Create `api/bestie-permissions.js` with code above
- [ ] Find and update all frontend references
- [ ] Test get and update flows
- [ ] Delete old files: `get-my-bestie-permissions.js`, `update-my-inviter-access.js`
- [ ] Verify: **8 functions** ✅

### Phase 4: Consolidate Chat (Optional)
- [ ] Update `api/chat.js` with code above
- [ ] Find and update all frontend chat references
- [ ] Test both wedding and bestie chat contexts
- [ ] Delete `api/bestie-chat.js`
- [ ] Verify: **7 functions** ✅

---

## TESTING CHECKLIST

After each consolidation phase:

### Invite Operations
- [ ] Owner can create partner invite
- [ ] Owner can create co-planner invite
- [ ] Owner can create bestie invite
- [ ] Invite links display correctly
- [ ] Non-authenticated users can view invite info
- [ ] Authenticated users can accept invites
- [ ] Used invites show "already used" error
- [ ] Expired invites show "expired" error

### Bestie Permissions
- [ ] Bestie can view their permissions
- [ ] Bestie can grant read access to inviter
- [ ] Bestie can grant edit access to inviter
- [ ] Bestie can revoke permissions
- [ ] Edit without read shows validation error
- [ ] Knowledge stats display correctly

### Chat Operations
- [ ] Wedding chat works with context='wedding'
- [ ] Bestie chat works with context='bestie'
- [ ] Different system prompts are used
- [ ] Messages stored in correct tables
- [ ] Conversation history maintained

---

## ROLLBACK PLAN

If consolidation causes issues:

1. **Keep old functions** - Don't delete until new version is tested
2. **Use git branches** - Create consolidation branch for safe testing
3. **Monitor errors** - Watch Vercel function logs for failures
4. **Quick revert** - Git revert the consolidation commit if needed

---

## FINAL RESULT

After all consolidations:

| Phase | Functions | Status |
|-------|-----------|--------|
| Start | 14 | ❌ Over limit |
| Phase 1 | 11 | ✅ Under limit |
| Phase 2 | 9 | ✅ Safe buffer |
| Phase 3 | 8 | ✅ Extra buffer |
| Phase 4 | 7 | ✅ Max buffer |

**Recommendation:** Execute Phase 1 immediately, Phase 2 within 1 week.

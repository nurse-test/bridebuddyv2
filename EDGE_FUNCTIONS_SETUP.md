# Supabase Edge Functions Setup Guide

This guide shows you how to implement the Edge Functions needed for bestie invite functionality.

## Prerequisites

- Supabase CLI installed (`npm install -g supabase`)
- Supabase project linked (`supabase link --project-ref YOUR_PROJECT_REF`)

## Edge Functions Location

Edge Functions should be deployed to your Supabase project at:
- `supabase/functions/create-invite/index.ts`
- `supabase/functions/join-wedding/index.ts`

---

## 1. Create Invite Edge Function

**Path:** `supabase/functions/create-invite/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { userToken, role = 'member' } = await req.json()

    // Validate role
    if (!['member', 'bestie'].includes(role)) {
      return new Response(
        JSON.stringify({ error: 'Invalid role. Must be "member" or "bestie"' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with user's token
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: `Bearer ${userToken}` } } }
    )

    // Get authenticated user
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Get user's wedding
    const { data: membership, error: membershipError } = await supabase
      .from('wedding_members')
      .select('wedding_id, role')
      .eq('user_id', user.id)
      .single()

    if (membershipError || !membership) {
      return new Response(
        JSON.stringify({ error: 'No wedding found' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Only owners can create invites
    if (membership.role !== 'owner') {
      return new Response(
        JSON.stringify({ error: 'Only wedding owners can create invites' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Generate unique invite code
    const code = generateInviteCode()

    // Create invite with role
    const { data: invite, error: inviteError } = await supabase
      .from('invite_codes')
      .insert({
        wedding_id: membership.wedding_id,
        code: code,
        created_by: user.id,
        role: role  // 'member' or 'bestie'
      })
      .select()
      .single()

    if (inviteError) {
      console.error('Error creating invite:', inviteError)
      return new Response(
        JSON.stringify({ error: 'Failed to create invite' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({
        inviteCode: invite.code,
        role: invite.role,
        weddingId: invite.wedding_id
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

function generateInviteCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' // Avoid confusing chars
  let code = ''
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return code
}
```

---

## 2. Join Wedding Edge Function

**Path:** `supabase/functions/join-wedding/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { inviteCode, userToken } = await req.json()

    if (!inviteCode) {
      return new Response(
        JSON.stringify({ error: 'Invite code is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with user's token
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: `Bearer ${userToken}` } } }
    )

    // Get authenticated user
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Look up invite code
    const { data: invite, error: inviteError } = await supabase
      .from('invite_codes')
      .select('*')
      .eq('code', inviteCode.toUpperCase())
      .eq('is_used', false)
      .single()

    if (inviteError || !invite) {
      return new Response(
        JSON.stringify({ error: 'Invalid or already used invite code' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Check if user is already a member
    const { data: existingMember } = await supabase
      .from('wedding_members')
      .select('*')
      .eq('wedding_id', invite.wedding_id)
      .eq('user_id', user.id)
      .single()

    if (existingMember) {
      return new Response(
        JSON.stringify({ error: 'You are already a member of this wedding' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Add user to wedding with the role from the invite
    const { error: memberError } = await supabase
      .from('wedding_members')
      .insert({
        wedding_id: invite.wedding_id,
        user_id: user.id,
        role: invite.role  // Use role from invite ('member' or 'bestie')
      })

    if (memberError) {
      console.error('Error adding member:', memberError)
      return new Response(
        JSON.stringify({ error: 'Failed to join wedding' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Mark invite as used
    const { error: updateError } = await supabase
      .from('invite_codes')
      .update({
        is_used: true,
        used_by: user.id
      })
      .eq('code', inviteCode.toUpperCase())

    if (updateError) {
      console.error('Error updating invite:', updateError)
      // Non-fatal - member was added successfully
    }

    return new Response(
      JSON.stringify({
        success: true,
        weddingId: invite.wedding_id,
        role: invite.role
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

---

## Deployment Steps

### 1. Initialize Supabase Functions (if not already done)

```bash
cd /home/user/bridebuddyv2
supabase init
```

### 2. Create Function Files

```bash
# Create create-invite function
supabase functions new create-invite
# Replace the contents of supabase/functions/create-invite/index.ts with the code above

# Create join-wedding function
supabase functions new join-wedding
# Replace the contents of supabase/functions/join-wedding/index.ts with the code above
```

### 3. Deploy Functions

```bash
# Deploy create-invite
supabase functions deploy create-invite

# Deploy join-wedding
supabase functions deploy join-wedding
```

### 4. Set Environment Variables (if needed)

The functions use these environment variables (automatically available in Supabase):
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

---

## Testing the Functions

### Test Create Invite (Member Role)

```bash
curl -X POST 'https://nluvnjydydotsrpluhey.supabase.co/functions/v1/create-invite' \
  -H "Authorization: Bearer YOUR_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{"userToken": "YOUR_USER_TOKEN", "role": "member"}'
```

### Test Create Invite (Bestie Role)

```bash
curl -X POST 'https://nluvnjydydotsrpluhey.supabase.co/functions/v1/create-invite' \
  -H "Authorization: Bearer YOUR_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{"userToken": "YOUR_USER_TOKEN", "role": "bestie"}'
```

### Test Join Wedding

```bash
curl -X POST 'https://nluvnjydydotsrpluhey.supabase.co/functions/v1/join-wedding' \
  -H "Authorization: Bearer YOUR_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{"userToken": "YOUR_USER_TOKEN", "inviteCode": "ABCD1234"}'
```

---

## Frontend Integration

### Creating a Bestie Invite

```javascript
// On invite-v2.html or dashboard
async function createBestieInvite() {
  const { data: { session } } = await supabase.auth.getSession()

  const response = await fetch('/api/create-invite', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userToken: session.access_token,
      role: 'bestie'  // Specify bestie role
    })
  })

  const { inviteCode, role } = await response.json()

  // Display code to user
  console.log(`Bestie invite code: ${inviteCode}`)
}
```

### Creating a Regular Member Invite

```javascript
async function createMemberInvite() {
  const { data: { session } } = await supabase.auth.getSession()

  const response = await fetch('/api/create-invite', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userToken: session.access_token,
      role: 'member'  // Regular member (default)
    })
  })

  const { inviteCode } = await response.json()
  console.log(`Member invite code: ${inviteCode}`)
}
```

### Joining with Invite Code

```javascript
// On invite-v2.html
async function joinWedding(code) {
  const { data: { session } } = await supabase.auth.getSession()

  const response = await fetch('/api/join-wedding', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      inviteCode: code,
      userToken: session.access_token
    })
  })

  const { success, weddingId, role } = await response.json()

  if (success) {
    // Redirect to appropriate dashboard
    if (role === 'bestie') {
      window.location.href = `bestie-v2.html?wedding_id=${weddingId}`
    } else {
      window.location.href = `dashboard-v2.html?wedding_id=${weddingId}`
    }
  }
}
```

---

## Security Notes

1. **RLS Policies**: Ensure your RLS policies allow:
   - Owners to create invites
   - Anyone with a valid invite to join
   - Members to see their own wedding data

2. **Role Validation**: Both Edge Functions validate roles to prevent invalid data

3. **Invite Code Format**: Uses uppercase letters and numbers, avoiding confusing characters (0/O, 1/I)

4. **Single Use**: Invite codes are marked as used after successful join

---

## Next Steps

1. **Run Database Setup**: Execute `setup_bestie_functionality.sql` in your Supabase SQL Editor
2. **Deploy Edge Functions**: Follow the deployment steps above
3. **Test End-to-End**: Create a bestie invite and test joining with it
4. **Update Frontend**: Add UI for creating different types of invites
5. **Verify RLS Policies**: Ensure all security policies are in place

---

## Troubleshooting

### Function Deployment Fails
- Ensure Supabase CLI is linked to your project
- Check that you're logged in: `supabase login`
- Verify project ref: `supabase projects list`

### Invite Creation Fails
- Check user is owner of a wedding
- Verify invite_codes table has role column
- Check RLS policies allow insert

### Join Wedding Fails
- Verify invite code exists and is unused
- Check wedding_members table allows bestie role
- Ensure user isn't already a member

### Role Not Applied
- Run `setup_bestie_functionality.sql` to add constraints
- Check invite_codes.role column exists
- Verify wedding_members.role check includes 'bestie'

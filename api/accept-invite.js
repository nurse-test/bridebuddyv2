// ============================================================================
// ACCEPT INVITE - UNIFIED FOR ALL ROLES
// ============================================================================
// Purpose: Accept invite and join wedding as partner, co-planner, or bestie
// One-time use with expiration enforcement
// ============================================================================

import { createClient } from '@supabase/supabase-js';

// Service role client (bypasses RLS for admin operations)
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const {
    invite_token,
    userToken,
    bestie_knowledge_permissions = { can_read: false, can_edit: false }
  } = req.body;

  // ========================================================================
  // STEP 1: Validate input
  // ========================================================================
  if (!invite_token || !userToken) {
    return res.status(400).json({
      error: 'Missing required fields: invite_token and userToken'
    });
  }

  // Validate bestie_knowledge_permissions structure
  if (typeof bestie_knowledge_permissions !== 'object' ||
      typeof bestie_knowledge_permissions.can_read !== 'boolean' ||
      typeof bestie_knowledge_permissions.can_edit !== 'boolean') {
    return res.status(400).json({
      error: 'Invalid bestie_knowledge_permissions. Must be { can_read: boolean, can_edit: boolean }'
    });
  }

  try {
    // ========================================================================
    // STEP 2: Authenticate the user
    // ========================================================================
    const supabaseUser = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_ANON_KEY,
      {
        global: {
          headers: {
            Authorization: `Bearer ${userToken}`
          }
        }
      }
    );

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return res.status(401).json({
        error: 'Unauthorized - invalid or expired token'
      });
    }

    // ========================================================================
    // STEP 3: Look up the invite by token
    // ========================================================================
    const { data: invite, error: inviteError } = await supabaseAdmin
      .from('invite_codes')
      .select('*')
      .eq('invite_token', invite_token)
      .single();

    if (inviteError || !invite) {
      return res.status(404).json({
        error: 'Invalid invite link'
      });
    }

    // ========================================================================
    // STEP 4: Check if invite has been used
    // ========================================================================
    if (invite.used === true) {
      return res.status(400).json({
        error: 'This invite has already been used'
      });
    }

    // ========================================================================
    // STEP 5: Check if invite has expired
    // ========================================================================
    const now = new Date();
    const expiresAt = new Date(invite.expires_at);

    if (expiresAt < now) {
      return res.status(400).json({
        error: 'This invite has expired',
        expires_at: invite.expires_at
      });
    }

    // ========================================================================
    // STEP 6: Check if user is already a member of this wedding
    // ========================================================================
    const { data: existingMember } = await supabaseAdmin
      .from('wedding_members')
      .select('role')
      .eq('wedding_id', invite.wedding_id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existingMember) {
      return res.status(400).json({
        error: 'You are already a member of this wedding',
        current_role: existingMember.role
      });
    }

    // ========================================================================
    // STEP 7: For bestie role - check 1:1 relationship constraint
    // ========================================================================
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
          error: 'This inviter already has a bestie for this wedding. Each person can only have one bestie.',
          details: 'The invite code may have been used by someone else.'
        });
      }
    }

    // ========================================================================
    // STEP 8: Add user to wedding_members
    // ========================================================================
    const { data: newMember, error: addMemberError } = await supabaseAdmin
      .from('wedding_members')
      .insert({
        wedding_id: invite.wedding_id,
        user_id: user.id,
        role: invite.role,
        invited_by_user_id: invite.created_by,
        wedding_profile_permissions: invite.wedding_profile_permissions
      })
      .select()
      .single();

    if (addMemberError) {
      console.error('Failed to add member:', addMemberError);
      return res.status(500).json({
        error: 'Failed to join wedding',
        details: addMemberError.message
      });
    }

    // ========================================================================
    // STEP 9: For bestie role - create bestie_permissions record
    // ========================================================================
    let bestiePermissions = null;

    if (invite.role === 'bestie') {
      const { data: permissions, error: permissionsError } = await supabaseAdmin
        .from('bestie_permissions')
        .insert({
          bestie_user_id: user.id,
          inviter_user_id: invite.created_by,
          wedding_id: invite.wedding_id,
          permissions: bestie_knowledge_permissions
        })
        .select()
        .single();

      if (permissionsError) {
        console.error('Failed to create bestie permissions:', permissionsError);
        // Don't fail the entire request - user is already a member
        // They can set permissions later
      } else {
        bestiePermissions = permissions;
      }
    }

    // ========================================================================
    // STEP 10: Mark invite as used
    // ========================================================================
    const { error: updateInviteError } = await supabaseAdmin
      .from('invite_codes')
      .update({
        used: true,
        used_by: user.id,
        used_at: new Date().toISOString()
      })
      .eq('invite_token', invite_token);

    if (updateInviteError) {
      console.error('Failed to mark invite as used:', updateInviteError);
      // Don't fail the request - user was added successfully
    }

    // ========================================================================
    // STEP 11: Fetch wedding details for response
    // ========================================================================
    const { data: wedding } = await supabaseAdmin
      .from('wedding_profiles')
      .select('partner1_name, partner2_name, wedding_date')
      .eq('id', invite.wedding_id)
      .single();

    // ========================================================================
    // STEP 12: Build role-specific response
    // ========================================================================
    const response = {
      success: true,
      message: getRoleMessage(invite.role),
      wedding: {
        id: invite.wedding_id,
        name: wedding ? `${wedding.partner1_name} & ${wedding.partner2_name}` : 'Unknown',
        date: wedding?.wedding_date || null
      },
      your_role: invite.role,
      permissions: {
        wedding_profile: invite.wedding_profile_permissions
      },
      redirect_to: `/dashboard-v2.html?wedding_id=${invite.wedding_id}`
    };

    // Add bestie-specific info
    if (invite.role === 'bestie' && bestiePermissions) {
      response.bestie_permissions = {
        inviter_access_to_your_knowledge: bestie_knowledge_permissions
      };
      response.next_steps = [
        'You now have a private bestie planning space',
        `Your inviter ${bestie_knowledge_permissions.can_read ? 'CAN' : 'CANNOT'} see your bestie knowledge`,
        'You can change their access anytime via Settings → Bestie Permissions',
        'Start planning surprises and events in your bestie dashboard!'
      ];
    }

    // Add partner-specific info
    if (invite.role === 'partner') {
      response.next_steps = [
        'You have full partner access to this wedding',
        'You can edit all wedding details',
        'You can invite additional co-planners and besties',
        'Start planning together!'
      ];
    }

    // Add co-planner-specific info
    if (invite.role === 'co_planner') {
      response.next_steps = [
        `You have ${invite.wedding_profile_permissions.edit ? 'edit' : 'view-only'} access to this wedding`,
        'You can help plan and coordinate details',
        invite.wedding_profile_permissions.edit
          ? 'You can make changes to wedding details'
          : 'You can request changes through the couple',
        'Welcome to the planning team!'
      ];
    }

    return res.status(200).json(response);

  } catch (error) {
    console.error('Accept invite error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
}

// ============================================================================
// HELPER: Get role-specific success message
// ============================================================================
function getRoleMessage(role) {
  const messages = {
    partner: 'Successfully joined as partner!',
    co_planner: 'Successfully joined as co-planner!',
    bestie: 'Successfully joined as bestie!'
  };
  return messages[role] || 'Successfully joined wedding!';
}

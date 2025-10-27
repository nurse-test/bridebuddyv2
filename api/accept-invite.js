// ============================================================================
// ACCEPT INVITE - SIMPLIFIED OWNER/BESTIE MODEL
// ============================================================================
// Purpose: Accept invite and join wedding as bestie
// One-time use with expiration enforcement
// Creates bestie_profile for new bestie members
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

  const { invite_token, userToken } = req.body;

  // ========================================================================
  // STEP 1: Validate input
  // ========================================================================
  if (!invite_token || !userToken) {
    return res.status(400).json({
      error: 'Missing required fields: invite_token and userToken'
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
    // STEP 7: Add user to wedding_members (simplified - no permissions)
    // ========================================================================
    const { data: newMember, error: addMemberError } = await supabaseAdmin
      .from('wedding_members')
      .insert({
        wedding_id: invite.wedding_id,
        user_id: user.id,
        role: invite.role,
        invited_by_user_id: invite.created_by
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
    // STEP 8: For bestie role - create bestie_profile
    // ========================================================================
    if (invite.role === 'bestie') {
      const { error: profileError } = await supabaseAdmin
        .from('bestie_profile')
        .insert({
          bestie_user_id: user.id,
          wedding_id: invite.wedding_id,
          bestie_brief: 'Welcome! Chat with me to start planning your bestie duties and surprises.'
        });

      if (profileError) {
        console.error('Failed to create bestie profile:', profileError);
        // Don't fail the entire request - user is already a member
        // Profile can be created later
      }
    }

    // ========================================================================
    // STEP 9: Mark invite as used
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
    // STEP 10: Fetch wedding details for response
    // ========================================================================
    const { data: wedding } = await supabaseAdmin
      .from('wedding_profiles')
      .select('partner1_name, partner2_name, wedding_date')
      .eq('id', invite.wedding_id)
      .single();

    // ========================================================================
    // STEP 11: Build simplified response
    // ========================================================================
    const response = {
      success: true,
      message: invite.role === 'bestie'
        ? 'Successfully joined as bestie!'
        : 'Successfully joined wedding!',
      wedding: {
        id: invite.wedding_id,
        name: wedding ? `${wedding.partner1_name} & ${wedding.partner2_name}` : 'Unknown',
        date: wedding?.wedding_date || null
      },
      your_role: invite.role,
      redirect_to: invite.role === 'bestie'
        ? `/bestie-luxury.html?wedding_id=${invite.wedding_id}`
        : `/dashboard-luxury.html?wedding_id=${invite.wedding_id}`
    };

    // Add bestie-specific info
    if (invite.role === 'bestie') {
      response.next_steps = [
        'You now have a private bestie planning space',
        'Chat with your AI assistant to plan bachelorette/bachelor parties',
        'Your bestie profile will be auto-populated with tasks and responsibilities',
        'Start planning surprises and events in your bestie dashboard!'
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


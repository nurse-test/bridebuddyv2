// ============================================================================
// ACCEPT BESTIE INVITE - VERCEL FUNCTION
// ============================================================================
// Purpose: Join wedding as bestie and establish 1:1 relationship with inviter
// Part of: Phase 2 - Bestie Permission System API Endpoints
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

  const { inviteCode, userToken } = req.body;

  // ============================================================================
  // STEP 1: Validate input
  // ============================================================================

  if (!inviteCode || !userToken) {
    return res.status(400).json({
      error: 'Missing required fields: inviteCode and userToken'
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
    // STEP 3: Look up the invite code
    // ========================================================================

    const { data: invite, error: inviteError } = await supabaseAdmin
      .from('invite_codes')
      .select('*')
      .eq('code', inviteCode.toUpperCase().trim())
      .eq('is_used', false)
      .single();

    if (inviteError || !invite) {
      return res.status(404).json({
        error: 'Invalid or already used invite code'
      });
    }

    // ========================================================================
    // STEP 4: Verify this is a bestie invite
    // ========================================================================

    if (invite.role !== 'bestie') {
      return res.status(400).json({
        error: 'This is not a bestie invite code. Use /api/join-wedding for regular member invites.'
      });
    }

    // ========================================================================
    // STEP 5: Check if user is already a member of this wedding
    // ========================================================================

    const { data: existingMember, error: memberCheckError } = await supabaseAdmin
      .from('wedding_members')
      .select('*')
      .eq('wedding_id', invite.wedding_id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existingMember) {
      return res.status(400).json({
        error: 'You are already a member of this wedding'
      });
    }

    // ========================================================================
    // STEP 6: Check if inviter already has a bestie for this wedding
    // ========================================================================
    // Each inviter can only have ONE bestie per wedding (1:1 relationship)

    const { data: existingBestie, error: bestieCheckError } = await supabaseAdmin
      .from('wedding_members')
      .select('user_id')
      .eq('wedding_id', invite.wedding_id)
      .eq('invited_by_user_id', invite.created_by)
      .eq('role', 'bestie')
      .maybeSingle();

    if (existingBestie) {
      return res.status(400).json({
        error: 'This inviter already has a bestie for this wedding. Each person can only have one bestie.',
        details: 'The invite code may have been used by someone else, or the inviter needs to create a new invite.'
      });
    }

    // ========================================================================
    // STEP 7: Add user to wedding_members with full relationship tracking
    // ========================================================================

    const { data: newMember, error: addMemberError } = await supabaseAdmin
      .from('wedding_members')
      .insert({
        wedding_id: invite.wedding_id,
        user_id: user.id,
        role: invite.role,
        invited_by_user_id: invite.created_by,  // Track who invited them
        wedding_profile_permissions: invite.wedding_profile_permissions || { can_read: false, can_edit: false }
      })
      .select()
      .single();

    if (addMemberError) {
      console.error('Failed to add bestie member:', addMemberError);
      return res.status(500).json({
        error: 'Failed to join wedding as bestie',
        details: addMemberError.message
      });
    }

    // ========================================================================
    // STEP 8: Create bestie_permissions record (default: no access)
    // ========================================================================
    // This establishes what access the inviter has to the bestie's knowledge

    const { data: permissions, error: permissionsError } = await supabaseAdmin
      .from('bestie_permissions')
      .insert({
        bestie_user_id: user.id,
        inviter_user_id: invite.created_by,
        wedding_id: invite.wedding_id,
        permissions: { can_read: false, can_edit: false }  // Default: inviter has no access
      })
      .select()
      .single();

    if (permissionsError) {
      console.error('Failed to create bestie permissions:', permissionsError);
      // Don't fail the entire request - user is already a member
      // Log error but continue
    }

    // ========================================================================
    // STEP 9: Mark invite code as used
    // ========================================================================

    const { error: updateInviteError } = await supabaseAdmin
      .from('invite_codes')
      .update({
        is_used: true,
        used_by: user.id,
        used_at: new Date().toISOString()
      })
      .eq('code', inviteCode.toUpperCase().trim());

    if (updateInviteError) {
      console.error('Failed to mark invite as used:', updateInviteError);
      // Don't fail the request - user was added successfully
    }

    // ========================================================================
    // STEP 10: Fetch additional info for response
    // ========================================================================

    // Get wedding details
    const { data: wedding, error: weddingError } = await supabaseAdmin
      .from('wedding_profiles')
      .select('wedding_name, wedding_date')
      .eq('id', invite.wedding_id)
      .single();

    // Get inviter details
    const { data: inviter, error: inviterError } = await supabaseAdmin
      .from('profiles')
      .select('full_name, email')
      .eq('id', invite.created_by)
      .single();

    // ========================================================================
    // STEP 11: Return success response
    // ========================================================================

    return res.status(200).json({
      success: true,
      message: 'Successfully joined as bestie!',
      relationship: {
        yourRole: 'bestie',
        invitedBy: {
          userId: invite.created_by,
          name: inviter?.full_name || 'Unknown',
          email: inviter?.email || 'Unknown'
        },
        wedding: {
          id: invite.wedding_id,
          name: wedding?.wedding_name || 'Unknown',
          date: wedding?.wedding_date || null
        },
        permissions: {
          yourAccessToWeddingProfile: invite.wedding_profile_permissions || { can_read: false, can_edit: false },
          inviterAccessToYourKnowledge: { can_read: false, can_edit: false }
        }
      },
      nextSteps: [
        'You now have a private bestie planning space',
        'Your inviter cannot see your bestie knowledge by default',
        'You can grant them access via Settings → Bestie Permissions',
        'Start planning surprises and events in your bestie dashboard!'
      ]
    });

  } catch (error) {
    console.error('Accept bestie invite error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
}

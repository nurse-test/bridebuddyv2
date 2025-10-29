// ============================================================================
// ACCEPT INVITE - UNIFIED FOR ALL ROLES
// ============================================================================
// Purpose: Accept invite and join wedding as partner or bestie
// One-time use (no time-based expiration)
// ============================================================================

import { createClient } from '@supabase/supabase-js';
import { handleCORS, rateLimitMiddleware, RATE_LIMITS } from './_utils/rate-limiter.js';

// Service role client (bypasses RLS for admin operations)
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  // Handle CORS preflight
  if (handleCORS(req, res)) {
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Apply rate limiting (60 requests per minute)
  if (!rateLimitMiddleware(req, res, RATE_LIMITS.RELAXED)) {
    return;
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
    // STEP 3: Ensure profile exists (don't rely on database trigger)
    // ========================================================================
    const { data: existingProfile } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('id', user.id)
      .single();

    if (!existingProfile) {
      // Create profile if it doesn't exist (trigger may not be deployed)
      const { error: profileError } = await supabaseAdmin
        .from('profiles')
        .insert({
          id: user.id,
          email: user.email,
          full_name: user.user_metadata?.full_name || ''
        });

      if (profileError) {
        console.error('Profile creation error:', profileError);
        return res.status(500).json({
          error: 'Failed to create user profile',
          details: profileError.message
        });
      }
    }

    // ========================================================================
    // STEP 4: Look up the invite by token
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
    // STEP 5: Check if invite has been used (one-time use only)
    // ========================================================================
    if (invite.is_used === true) {
      return res.status(400).json({
        error: 'This invite has already been used'
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
    // STEP 9: Role-specific setup
    // ========================================================================
    if (invite.role === 'bestie') {
      // Create bestie_profile for bestie role
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
      }

      // Create bestie_permissions entry to track what inviter can access
      const { error: permissionsError } = await supabaseAdmin
        .from('bestie_permissions')
        .insert({
          bestie_user_id: user.id,
          inviter_user_id: invite.created_by,
          wedding_id: invite.wedding_id,
          permissions: bestie_knowledge_permissions
        });

      if (permissionsError) {
        console.error('Failed to create bestie permissions:', permissionsError);
        // Don't fail the entire request - user is already a member
      }
    } else if (invite.role === 'partner') {
      // Partner joins as co-owner, no additional setup needed
      // They will share the same wedding_profiles, vendor_tracker, budget_tracker, wedding_tasks
    }

    // ========================================================================
    // STEP 10: Mark invite as used
    // ========================================================================
    const { error: updateInviteError } = await supabaseAdmin
      .from('invite_codes')
      .update({
        is_used: true,
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
      redirect_to: `/dashboard-luxury.html?wedding_id=${invite.wedding_id}`
    };

    // Add role-specific info
    if (invite.role === 'partner') {
      response.next_steps = [
        'Welcome to your shared wedding planning space!',
        'You and your partner can both chat with the AI to plan your wedding',
        'All wedding details, vendors, budget, and tasks are shared between you',
        'Start planning together in your Wedding Chat!'
      ];
    } else if (invite.role === 'bestie') {
      response.next_steps = [
        'You now have a private bestie planning space',
        'Use the Bestie Chat to plan bachelorette/bachelor parties and bridal showers',
        'Your planning space is separate from the main wedding planning',
        'Start planning surprises and events in your bestie dashboard!'
      ];
    }

    return res.status(200).json(response);

  } catch (error) {
    // Security: Only log error message, not full error object (contains invite tokens, user IDs, wedding IDs, roles)
    console.error('Accept invite error:', error.message || 'Unknown error');
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

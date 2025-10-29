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
    userToken
  } = req.body;

  // ========================================================================
  // STEP 1: Validate input
  // ========================================================================
  if (!invite_token || !userToken) {
    return res.status(400).json({
      error: 'Missing required fields: invite_token and userToken'
    });
  }

  try {
    console.log('🔵 [ACCEPT-INVITE] Starting invite acceptance process');
    console.log('🔵 [ACCEPT-INVITE] Invite token received:', invite_token ? 'YES' : 'NO');

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
      console.error('❌ [ACCEPT-INVITE] Authentication failed:', authError?.message);
      return res.status(401).json({
        error: 'Unauthorized - invalid or expired token'
      });
    }

    console.log('✅ [ACCEPT-INVITE] User authenticated:', user.id);

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
    // Base schema uses 'code' column, migration 006 adds 'invite_token'
    // Try both for compatibility
    let invite, inviteError;

    // First try invite_token (migration 006)
    const tokenResult = await supabaseAdmin
      .from('invite_codes')
      .select('*')
      .eq('invite_token', invite_token)
      .maybeSingle();

    if (tokenResult.data) {
      invite = tokenResult.data;
      inviteError = tokenResult.error;
    } else {
      // Fall back to code column (base schema)
      const codeResult = await supabaseAdmin
        .from('invite_codes')
        .select('*')
        .eq('code', invite_token)
        .maybeSingle();

      invite = codeResult.data;
      inviteError = codeResult.error;
    }

    if (inviteError || !invite) {
      console.error('❌ [ACCEPT-INVITE] Invite not found:', inviteError?.message || 'No invite record');
      return res.status(404).json({
        error: 'Invalid invite link'
      });
    }

    // ========================================================================
    // Extract role from token (base schema compatibility)
    // ========================================================================
    // Base schema doesn't have 'role' column in invite_codes
    // We encode it in the token: "partner_TOKEN" or "bestie_TOKEN"
    // Extract the role prefix from the token
    let intendedRole = 'partner';  // Default
    if (invite_token.includes('_')) {
      const parts = invite_token.split('_');
      if (parts[0] === 'partner' || parts[0] === 'bestie') {
        intendedRole = parts[0];
      }
    }

    // Override with database role if present (for migrated schemas)
    if (invite.role) {
      intendedRole = invite.role;
    }

    console.log('✅ [ACCEPT-INVITE] Invite found:', {
      id: invite.id,
      wedding_id: invite.wedding_id,
      is_used: invite.is_used,
      role: intendedRole
    });

    // ONLY 3 valid roles: owner, partner, bestie
    // Use the intended role directly
    const dbRole = intendedRole;

    // Set permissions based on role:
    // - Owner: Full access (read + edit)
    // - Partner: Full access (read + edit)
    // - Bestie: View access (read only, no edit)
    // IMPORTANT: Database constraint requires can_read and can_edit keys (not read/edit)
    const wedding_profile_permissions = (intendedRole === 'owner' || intendedRole === 'partner')
      ? { can_read: true, can_edit: true }  // Full access for owner and partner
      : intendedRole === 'bestie'
      ? { can_read: true, can_edit: false }  // View only for bestie
      : { can_read: false, can_edit: false };  // Default no access

    // ========================================================================
    // STEP 5: Check if invite has expired
    // ========================================================================
    if (invite.expires_at) {
      const now = new Date();
      const expiresAt = new Date(invite.expires_at);

      if (expiresAt < now) {
        return res.status(400).json({
          error: 'This invite link has expired. Please request a new invite from the wedding couple.'
        });
      }
    }

    // ========================================================================
    // STEP 6: Check if invite has been used (one-time use only)
    // ========================================================================
    if (invite.is_used === true) {
      return res.status(400).json({
        error: 'This invite has already been used'
      });
    }

    // ========================================================================
    // STEP 7: Check if user is already a member of this wedding
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
    // STEP 8: For bestie role - check 1:1 relationship constraint
    // ========================================================================
    if (intendedRole === 'bestie') {
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
    // STEP 9: Add user to wedding_members
    // ========================================================================
    console.log('🔵 [ACCEPT-INVITE] Adding user to wedding_members:', {
      wedding_id: invite.wedding_id,
      user_id: user.id,
      role: dbRole,
      invited_by: invite.created_by
    });

    const { error: addMemberError } = await supabaseAdmin
      .from('wedding_members')
      .insert({
        wedding_id: invite.wedding_id,
        user_id: user.id,
        role: dbRole,  // 'owner', 'partner', or 'bestie'
        invited_by_user_id: invite.created_by,
        wedding_profile_permissions: wedding_profile_permissions
      })
      .select()
      .single();

    if (addMemberError) {
      console.error('❌ [ACCEPT-INVITE] Failed to add member:', {
        error: addMemberError.message,
        code: addMemberError.code,
        details: addMemberError.details
      });
      return res.status(500).json({
        error: 'Failed to join wedding',
        details: addMemberError.message
      });
    }

    console.log('✅ [ACCEPT-INVITE] User added to wedding_members successfully');

    // ========================================================================
    // STEP 10: Role-specific setup
    // ========================================================================
    if (intendedRole === 'bestie') {
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

      // NOTE: No longer creating bestie_permissions entry
      // Permissions are now FIXED by role:
      // - Besties have ZERO access to bestie_knowledge (each bestie only sees their own)
      // - Besties have VIEW-ONLY access to wedding_profiles (hardcoded in RLS)
    } else if (intendedRole === 'partner') {
      // Partner joins as 'partner' role with full access (same as owner)
      // They will share the same wedding_profiles, vendor_tracker, budget_tracker, wedding_tasks
    }

    // ========================================================================
    // STEP 11: Mark invite as used (use ID not token for reliability)
    // ========================================================================
    const { error: updateInviteError } = await supabaseAdmin
      .from('invite_codes')
      .update({
        is_used: true,
        used_by: user.id,
        used_at: new Date().toISOString()
      })
      .eq('id', invite.id);  // Use ID instead of token - works for both base and migration schemas

    if (updateInviteError) {
      console.error('⚠️ [ACCEPT-INVITE] Failed to mark invite as used:', {
        error: updateInviteError.message,
        code: updateInviteError.code,
        invite_id: invite.id
      });
      // Don't fail the request - user was added successfully
    } else {
      console.log('✅ [ACCEPT-INVITE] Invite marked as used');
    }

    // ========================================================================
    // STEP 12: Fetch wedding details for response
    // ========================================================================
    const { data: wedding } = await supabaseAdmin
      .from('wedding_profiles')
      .select('partner1_name, partner2_name, wedding_date')
      .eq('id', invite.wedding_id)
      .single();

    // ========================================================================
    // STEP 13: Build role-specific response
    // ========================================================================
    const response = {
      success: true,
      message: getRoleMessage(intendedRole),
      wedding: {
        id: invite.wedding_id,
        name: wedding ? `${wedding.partner1_name} & ${wedding.partner2_name}` : 'Unknown',
        date: wedding?.wedding_date || null
      },
      your_role: intendedRole,  // Show the intended role (partner/bestie) not DB role (member/bestie)
      permissions: {
        wedding_profile: wedding_profile_permissions
      },
      // Besties go to bestie dashboard, owner/partner go to main dashboard
      redirect_to: intendedRole === 'bestie'
        ? `/bestie-dashboard-luxury.html?wedding_id=${invite.wedding_id}`
        : `/dashboard-luxury.html?wedding_id=${invite.wedding_id}`
    };

    // Add role-specific info
    if (intendedRole === 'partner') {
      response.next_steps = [
        'Welcome to your shared wedding planning space!',
        'You and your partner can both chat with the AI to plan your wedding',
        'All wedding details, vendors, budget, and tasks are shared between you',
        'Start planning together in your Wedding Chat!'
      ];
    } else if (intendedRole === 'bestie') {
      response.next_steps = [
        'You now have a private bestie planning space',
        'Use the Bestie Chat to plan bachelorette/bachelor parties and bridal showers',
        'You can view wedding details for planning',
        'Start planning surprises and events in your bestie dashboard!'
      ];
    }

    console.log('✅ [ACCEPT-INVITE] Invite acceptance complete, returning success');
    return res.status(200).json(response);

  } catch (error) {
    // Security: Only log error message, not full error object (contains invite tokens, user IDs, wedding IDs, roles)
    console.error('❌ [ACCEPT-INVITE] Critical error:', {
      message: error.message,
      stack: error.stack?.split('\n')[0]  // First line of stack trace only
    });
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
}

// ============================================================================
// HELPER: Get role-specific success message
// ============================================================================
// Only 3 valid roles: owner, partner, bestie
function getRoleMessage(role) {
  const messages = {
    owner: 'Successfully joined as owner!',
    partner: 'Successfully joined as partner!',
    bestie: 'Successfully joined as bestie!'
  };
  return messages[role] || 'Successfully joined wedding!';
}

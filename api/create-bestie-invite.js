// ============================================================================
// CREATE BESTIE INVITE - VERCEL FUNCTION
// ============================================================================
// Purpose: Create bestie invite with granular wedding profile permissions
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

  const {
    userToken,
    role = 'bestie',
    wedding_profile_permissions = { can_read: false, can_edit: false }
  } = req.body;

  // ============================================================================
  // STEP 1: Validate input
  // ============================================================================

  // Validate role (this endpoint is specifically for bestie invites)
  if (role !== 'bestie') {
    return res.status(400).json({
      error: 'Invalid role. This endpoint is for bestie invites only. Use /api/create-invite for regular members.'
    });
  }

  // Validate permissions structure
  if (
    typeof wedding_profile_permissions !== 'object' ||
    typeof wedding_profile_permissions.can_read !== 'boolean' ||
    typeof wedding_profile_permissions.can_edit !== 'boolean'
  ) {
    return res.status(400).json({
      error: 'Invalid wedding_profile_permissions. Must be: {"can_read": boolean, "can_edit": boolean}'
    });
  }

  // ============================================================================
  // STEP 2: Authenticate the user
  // ============================================================================

  try {
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
    // STEP 3: Verify user is the wedding owner
    // ========================================================================

    const { data: membership, error: membershipError } = await supabaseAdmin
      .from('wedding_members')
      .select('wedding_id, role')
      .eq('user_id', user.id)
      .single();

    if (membershipError || !membership) {
      return res.status(404).json({
        error: 'You are not a member of any wedding'
      });
    }

    if (membership.role !== 'owner') {
      return res.status(403).json({
        error: 'Only wedding owners can create bestie invites'
      });
    }

    // ========================================================================
    // STEP 4: Check if wedding has bestie addon enabled
    // ========================================================================

    const { data: wedding, error: weddingError } = await supabaseAdmin
      .from('wedding_profiles')
      .select('bestie_addon_enabled')
      .eq('id', membership.wedding_id)
      .single();

    if (weddingError || !wedding) {
      return res.status(404).json({
        error: 'Wedding not found'
      });
    }

    if (!wedding.bestie_addon_enabled) {
      return res.status(403).json({
        error: 'Bestie addon is not enabled for your wedding. Please upgrade your plan.'
      });
    }

    // ========================================================================
    // STEP 5: Generate unique invite code
    // ========================================================================

    const inviteCode = generateInviteCode();

    // ========================================================================
    // STEP 6: Insert invite into database with permissions
    // ========================================================================

    const { data: invite, error: insertError } = await supabaseAdmin
      .from('invite_codes')
      .insert({
        wedding_id: membership.wedding_id,
        code: inviteCode,
        created_by: user.id,
        role: role,
        wedding_profile_permissions: wedding_profile_permissions,
        is_used: false
      })
      .select()
      .single();

    if (insertError) {
      console.error('Failed to create bestie invite:', insertError);
      return res.status(500).json({
        error: 'Failed to create bestie invite code',
        details: insertError.message
      });
    }

    // ========================================================================
    // STEP 7: Return success response with invite details
    // ========================================================================

    return res.status(200).json({
      success: true,
      inviteCode: invite.code,
      role: invite.role,
      weddingId: invite.wedding_id,
      permissions: {
        weddingProfile: wedding_profile_permissions
      },
      message: 'Bestie invite created successfully',
      instructions: 'Share this code with your Maid of Honor or Best Man. They will have a 1:1 relationship with you and can manage permissions for what you can see in their private planning space.'
    });

  } catch (error) {
    console.error('Create bestie invite error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
}

// ============================================================================
// HELPER: Generate random 8-character invite code
// ============================================================================
function generateInviteCode() {
  // Use characters that are easy to read and communicate
  // Excludes: 0, O, 1, I, L (to avoid confusion)
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';

  for (let i = 0; i < 8; i++) {
    const randomIndex = Math.floor(Math.random() * chars.length);
    code += chars.charAt(randomIndex);
  }

  return code;
}

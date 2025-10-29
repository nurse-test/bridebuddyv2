// ============================================================================
// GET INVITE INFO - PUBLIC ENDPOINT
// ============================================================================
// Validates invite token and returns invite details
// Accessible without authentication (for new users clicking invite links)
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

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Apply rate limiting (60 requests per minute)
  if (!rateLimitMiddleware(req, res, RATE_LIMITS.RELAXED)) {
    return;
  }

  const { invite_token } = req.query;

  // ========================================================================
  // STEP 1: Validate input
  // ========================================================================
  if (!invite_token) {
    return res.status(400).json({
      error: 'Missing required parameter: invite_token'
    });
  }

  try {
    // ========================================================================
    // STEP 2: Look up invite by token
    // ========================================================================
    const { data: invite, error: inviteError } = await supabaseAdmin
      .from('invite_codes')
      .select(`
        id,
        wedding_id,
        role,
        wedding_profile_permissions,
        created_by,
        is_used,
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

    // ========================================================================
    // STEP 3: Check if invite has been used (one-time use only)
    // ========================================================================
    if (invite.is_used === true) {
      return res.status(400).json({
        error: 'This invite has already been used',
        is_valid: false,
        is_used: true
      });
    }

    // ========================================================================
    // STEP 4: Get wedding details
    // ========================================================================
    const { data: wedding, error: weddingError } = await supabaseAdmin
      .from('wedding_profiles')
      .select('partner1_name, partner2_name, wedding_date')
      .eq('id', invite.wedding_id)
      .single();

    if (weddingError || !wedding) {
      return res.status(500).json({
        error: 'Failed to retrieve wedding details'
      });
    }

    // ========================================================================
    // STEP 5: Get inviter details
    // ========================================================================
    const { data: inviter, error: inviterError } = await supabaseAdmin
      .from('auth.users')
      .select('id, email, raw_user_meta_data')
      .eq('id', invite.created_by)
      .single();

    // Get inviter name from wedding_members or user metadata
    let inviterName = 'Wedding Owner';
    if (!inviterError && inviter) {
      // Try to get name from user metadata
      if (inviter.raw_user_meta_data?.full_name) {
        inviterName = inviter.raw_user_meta_data.full_name;
      } else if (inviter.raw_user_meta_data?.name) {
        inviterName = inviter.raw_user_meta_data.name;
      } else {
        // Check if inviter is partner1 or partner2
        if (wedding.partner1_name) {
          inviterName = wedding.partner1_name;
        }
      }
    }

    // ========================================================================
    // STEP 6: Format role display name
    // ========================================================================
    const roleDisplayNames = {
      partner: 'Partner',
      co_planner: 'Co-planner',
      bestie: 'Bestie (MOH/Best Man)'
    };

    const roleDisplay = roleDisplayNames[invite.role] || invite.role;

    // ========================================================================
    // STEP 7: Return invite details
    // ========================================================================
    return res.status(200).json({
      success: true,
      is_valid: true,
      invite: {
        wedding_name: `${wedding.partner1_name} & ${wedding.partner2_name}`,
        wedding_date: wedding.wedding_date,
        inviter_name: inviterName,
        role: invite.role,
        role_display: roleDisplay,
        wedding_profile_permissions: invite.wedding_profile_permissions,
        created_at: invite.created_at,
        one_time_use: true
      },
      permissions: {
        can_read_wedding_profile: invite.wedding_profile_permissions.read,
        can_edit_wedding_profile: invite.wedding_profile_permissions.edit
      }
    });

  } catch (error) {
    // Security: Only log error message, not full error object (contains invite tokens, wedding IDs, couple names)
    console.error('Get invite info error:', error.message || 'Unknown error');
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
}

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
      return res.status(404).json({
        error: 'Invalid invite link',
        is_valid: false
      });
    }

    // ========================================================================
    // STEP 3: Check if invite has expired
    // ========================================================================
    const now = new Date();
    const expiresAt = new Date(invite.expires_at);

    if (expiresAt < now) {
      return res.status(400).json({
        error: 'This invite link has expired',
        is_valid: false,
        is_expired: true
      });
    }

    // ========================================================================
    // STEP 4: Check if invite has been used (one-time use only)
    // ========================================================================
    if (invite.is_used === true) {
      return res.status(400).json({
        error: 'This invite has already been used',
        is_valid: false,
        is_used: true
      });
    }

    // ========================================================================
    // STEP 5: Get wedding details
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
    // STEP 6: Get inviter details
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
    // STEP 6: Extract role from token and format display
    // ========================================================================
    // Base schema doesn't have 'role' column in invite_codes
    // We encode it in the token: "partner_TOKEN" or "bestie_TOKEN"
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

    const roleDisplayNames = {
      partner: 'Partner',
      co_planner: 'Co-planner',
      bestie: 'Bestie (MOH/Best Man)'
    };
    const roleDisplay = roleDisplayNames[intendedRole] || 'Wedding Team Member';

    // Set permissions based on intended role
    const permissions = intendedRole === 'partner'
      ? { read: true, edit: true }  // Partner gets full access
      : intendedRole === 'bestie'
      ? { read: false, edit: false }  // Bestie gets no wedding profile access
      : { read: true, edit: false };  // Default view-only

    // Override with database permissions if present (for migrated schemas)
    const finalPermissions = invite.wedding_profile_permissions || permissions;

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
        role: intendedRole,
        role_display: roleDisplay,
        wedding_profile_permissions: finalPermissions,
        created_at: invite.created_at,
        one_time_use: true
      },
      permissions: {
        can_read_wedding_profile: finalPermissions.read,
        can_edit_wedding_profile: finalPermissions.edit
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

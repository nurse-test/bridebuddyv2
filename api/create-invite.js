// ============================================================================
// CREATE INVITE - UNIFIED SYSTEM FOR ALL ROLES
// ============================================================================
// Creates one-time-use invite links for partner and bestie roles
// Link becomes invalid after first use (no time-based expiration)
// ============================================================================

import { createClient } from '@supabase/supabase-js';
import { randomBytes } from 'crypto';
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

  const { userToken, role } = req.body;

  // ========================================================================
  // STEP 1: Validate input
  // ========================================================================
  if (!role || !['partner', 'bestie'].includes(role)) {
    return res.status(400).json({
      error: 'Invalid role. Must be "partner" or "bestie"'
    });
  }

  if (!userToken) {
    return res.status(400).json({
      error: 'Missing required field: userToken'
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

    // Both owner and partner can create invites
    if (!['owner', 'partner'].includes(membership.role)) {
      return res.status(403).json({
        error: 'Only wedding owners can create invite links'
      });
    }

    // ========================================================================
    // STEP 3.5: Check role limits before creating invite
    // ========================================================================
    const { data: existingMembers } = await supabaseAdmin
      .from('wedding_members')
      .select('role')
      .eq('wedding_id', membership.wedding_id);

    if (role === 'partner') {
      const hasPartner = existingMembers?.some(m => m.role === 'partner');
      if (hasPartner) {
        return res.status(400).json({
          error: 'This wedding already has a partner. Only 1 partner allowed per wedding.'
        });
      }
    }

    if (role === 'bestie') {
      const bestieCount = existingMembers?.filter(m => m.role === 'bestie').length || 0;
      if (bestieCount >= 2) {
        return res.status(400).json({
          error: 'This wedding already has 2 besties. Maximum 2 besties allowed per wedding.'
        });
      }
    }

    // ========================================================================
    // STEP 4: Get wedding details for response
    // ========================================================================
    const { data: wedding, error: weddingError } = await supabaseAdmin
      .from('wedding_profiles')
      .select('partner1_name, partner2_name')
      .eq('id', membership.wedding_id)
      .single();

    if (weddingError || !wedding) {
      return res.status(500).json({
        error: 'Failed to retrieve wedding details'
      });
    }

    // ========================================================================
    // STEP 5: Generate secure invite token
    // ========================================================================
    const inviteToken = generateSecureToken();

    // ========================================================================
    // STEP 6: Insert into database (one-time use, no expiration)
    // ========================================================================
    const { data: invite, error: insertError } = await supabaseAdmin
      .from('invite_codes')
      .insert({
        wedding_id: membership.wedding_id,
        invite_token: inviteToken,
        created_by: user.id,
        role: role,
        wedding_profile_permissions: { read: true, edit: role === 'partner' },
        used: false
      })
      .select()
      .single();

    if (insertError) {
      console.error('Failed to create invite:', insertError);
      return res.status(500).json({
        error: 'Failed to create invite link',
        details: insertError.message
      });
    }

    // ========================================================================
    // STEP 7: Build invite URL
    // ========================================================================
    const baseUrl = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : 'https://bridebuddyv2.vercel.app';

    const inviteUrl = `${baseUrl}/accept-invite.html?token=${inviteToken}`;

    // ========================================================================
    // STEP 8: Return success response
    // ========================================================================
    return res.status(200).json({
      success: true,
      invite_url: inviteUrl,
      invite_token: inviteToken,
      role: invite.role,
      wedding_profile_permissions: invite.wedding_profile_permissions,
      wedding_name: `${wedding.partner1_name} & ${wedding.partner2_name}`,
      message: role === 'partner'
        ? 'Partner invite link created! Share this with your fiancé(e). This is a one-time use link.'
        : 'Bestie invite link created! Share this with your Maid of Honor or Best Man. This is a one-time use link.'
    });

  } catch (error) {
    // Security: Only log error message, not full error object (contains wedding IDs, user IDs, invite tokens, roles)
    console.error('Create invite error:', error.message || 'Unknown error');
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
}

// ============================================================================
// HELPER: Generate cryptographically secure token
// ============================================================================
function generateSecureToken() {
  // Generate 32 random bytes and convert to base64url
  // This creates a token like: "a3K9mN2pQ7xR5vL8wT1yZ4bC6dE0fH3j"
  return randomBytes(32)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

// ============================================================================
// HELPER: Get role-specific message
// ============================================================================
function getRoleMessage(role) {
  const messages = {
    partner: 'Partner invite link created successfully',
    co_planner: 'Co-planner invite link created successfully',
    bestie: 'Bestie invite link created successfully'
  };
  return messages[role] || 'Invite link created successfully';
}

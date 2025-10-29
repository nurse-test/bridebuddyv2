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

  const { userToken, wedding_id, role } = req.body;

  // ========================================================================
  // STEP 1: Validate input
  // ========================================================================
  if (!userToken) {
    return res.status(400).json({
      error: 'Missing required field: userToken'
    });
  }

  if (!wedding_id) {
    return res.status(400).json({
      error: 'Missing required field: wedding_id'
    });
  }

  if (!role || !['partner', 'bestie'].includes(role)) {
    return res.status(400).json({
      error: 'Invalid role. Must be "partner" or "bestie"'
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
    // STEP 3: Verify user is a member of the specified wedding
    // ========================================================================
    const { data: membership, error: membershipError } = await supabaseAdmin
      .from('wedding_members')
      .select('wedding_id, role')
      .eq('user_id', user.id)
      .eq('wedding_id', wedding_id)
      .maybeSingle();

    if (membershipError) {
      console.error('Wedding membership lookup failed:', {
        user_id: user.id,
        wedding_id: wedding_id,
        error: membershipError?.message,
        code: membershipError?.code
      });
      return res.status(500).json({
        error: 'Failed to verify wedding membership',
        details: membershipError?.message
      });
    }

    if (!membership) {
      return res.status(403).json({
        error: 'You are not a member of this wedding'
      });
    }

    // Both owner and partner can create invites
    if (!['owner', 'partner'].includes(membership.role)) {
      return res.status(403).json({
        error: 'Only wedding owners and partners can create invite links'
      });
    }

    // ========================================================================
    // STEP 3.5: Check role limits before creating invite
    // ========================================================================
    const { data: existingMembers } = await supabaseAdmin
      .from('wedding_members')
      .select('role, invited_by_user_id')
      .eq('wedding_id', wedding_id);

    if (role === 'partner') {
      const hasPartner = existingMembers?.some(m => m.role === 'partner');
      if (hasPartner) {
        return res.status(400).json({
          error: 'This wedding already has a partner. Only 1 partner allowed per wedding.'
        });
      }
    }

    if (role === 'bestie') {
      // Check 1: Max 2 besties per wedding
      const bestieCount = existingMembers?.filter(m => m.role === 'bestie').length || 0;
      if (bestieCount >= 2) {
        return res.status(400).json({
          error: 'This wedding already has 2 besties. Maximum 2 besties allowed per wedding.'
        });
      }

      // Check 2: Each person (owner/partner) can only invite 1 bestie
      const userAlreadyInvitedBestie = existingMembers?.some(
        m => m.role === 'bestie' && m.invited_by_user_id === user.id
      );
      if (userAlreadyInvitedBestie) {
        return res.status(400).json({
          error: 'You have already invited a bestie. Each person can only invite 1 bestie.'
        });
      }

      // Check 3: Make sure there's not already a pending invite from this user
      const { data: pendingInvites } = await supabaseAdmin
        .from('invite_codes')
        .select('id')
        .eq('wedding_id', wedding_id)
        .eq('created_by', user.id)
        .eq('role', 'bestie')
        .or('is_used.is.null,is_used.eq.false');

      if (pendingInvites && pendingInvites.length > 0) {
        return res.status(400).json({
          error: 'You already have a pending bestie invite. Please wait for it to be accepted or delete it first.'
        });
      }
    }

    // ========================================================================
    // STEP 4: Get wedding details for response
    // ========================================================================
    const { data: wedding, error: weddingError } = await supabaseAdmin
      .from('wedding_profiles')
      .select('partner1_name, partner2_name')
      .eq('id', wedding_id)
      .single();

    if (weddingError || !wedding) {
      console.error('Wedding lookup failed:', {
        wedding_id: wedding_id,
        error: weddingError?.message,
        code: weddingError?.code
      });
      return res.status(500).json({
        error: 'Failed to retrieve wedding details',
        details: weddingError?.message
      });
    }

    // ========================================================================
    // STEP 5: Generate secure invite token with role encoded
    // ========================================================================
    // Base schema doesn't have 'role' column in invite_codes, so we encode
    // the role in the token itself: "partner_TOKEN" or "bestie_TOKEN"
    // This allows us to track the intended role even without the column
    const randomToken = generateSecureToken();
    const inviteToken = `${role}_${randomToken}`;

    // ========================================================================
    // STEP 6: Insert into database (base schema compatibility)
    // ========================================================================
    // Base database schema ONLY has these columns:
    //   - wedding_id, code, created_by, is_used, used_by, created_at, used_at
    // Migration 006 adds: invite_token, role, wedding_profile_permissions, expires_at
    //
    // For now, we only use base schema columns to ensure compatibility

    const { data: invite, error: insertError } = await supabaseAdmin
      .from('invite_codes')
      .insert({
        wedding_id: wedding_id,
        code: inviteToken,  // Base schema uses 'code' not 'invite_token'
        created_by: user.id,
        is_used: false
      })
      .select()
      .single();

    if (insertError) {
      console.error('Failed to create invite:', {
        wedding_id: wedding_id,
        role: role,
        error: insertError.message,
        code: insertError.code,
        details: insertError.details,
        hint: insertError.hint
      });
      return res.status(500).json({
        error: 'Failed to create invite link',
        details: insertError.message,
        hint: insertError.hint
      });
    }

    // ========================================================================
    // STEP 7: Build invite URL
    // ========================================================================
    // IMPORTANT: Do NOT use VERCEL_URL as it points to Vercel's internal deployment URLs
    // which require Vercel authentication. Always use the public production domain.
    const baseUrl = process.env.PUBLIC_APP_URL || 'https://bridebuddyv2.vercel.app';
    const inviteUrl = `${baseUrl}/accept-invite-luxury.html?token=${inviteToken}`;

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


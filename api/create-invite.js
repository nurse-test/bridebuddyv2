// ============================================================================
// CREATE INVITE - SIMPLIFIED OWNER/BESTIE SYSTEM
// ============================================================================
// Creates one-time-use invite links for bestie role only
// Returns shareable URL that expires in 7 days
// ============================================================================

import { createClient } from '@supabase/supabase-js';
import { randomBytes } from 'crypto';

// Service role client (bypasses RLS for admin operations)
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
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
    // STEP 6: Set expiration (7 days from now)
    // ========================================================================
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    // ========================================================================
    // STEP 7: Insert into database (simplified - no permissions)
    // ========================================================================
    // Generate a simple code for display (6-char readable code)
    const displayCode = randomBytes(3).toString('hex').toUpperCase();

    const { data: invite, error: insertError } = await supabaseAdmin
      .from('invite_codes')
      .insert({
        wedding_id: membership.wedding_id,
        code: displayCode,
        invite_token: inviteToken,
        created_by: user.id,
        role: role,
        is_used: false,
        used: false,
        expires_at: expiresAt.toISOString()
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
    // STEP 8: Build invite URL
    // ========================================================================
    const baseUrl = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : 'https://bridebuddyv2.vercel.app';

    const inviteUrl = `${baseUrl}/accept-invite.html?token=${inviteToken}`;

    // ========================================================================
    // STEP 9: Return success response (simplified)
    // ========================================================================
    return res.status(200).json({
      success: true,
      invite_url: inviteUrl,
      invite_token: inviteToken,
      role: invite.role,
      expires_at: invite.expires_at,
      wedding_name: `${wedding.partner1_name} & ${wedding.partner2_name}`,
      message: role === 'partner'
        ? 'Partner invite link created! Share this with your fiancé(e).'
        : 'Bestie invite link created! Share this with your Maid of Honor or Best Man.'
    });

  } catch (error) {
    console.error('Create invite error:', error);
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


// ============================================================================
// CREATE INVITE - VERCEL FUNCTION (DIRECT IMPLEMENTATION)
// ============================================================================
// Generates invite codes for owners to share with co-planners or besties
// Replaces proxy pattern - now implements logic directly in Vercel
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

  const { userToken, role = 'member' } = req.body;

  // Validate role
  if (!['member', 'bestie'].includes(role)) {
    return res.status(400).json({
      error: 'Invalid role. Must be "member" or "bestie"'
    });
  }

  try {
    // ========================================================================
    // STEP 1: Authenticate the user
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
    // STEP 2: Verify user is the wedding owner
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
        error: 'Only wedding owners can create invite codes'
      });
    }

    // ========================================================================
    // STEP 3: Generate unique invite code
    // ========================================================================
    const inviteCode = generateInviteCode();

    // ========================================================================
    // STEP 4: Insert into database
    // ========================================================================
    const { data: invite, error: insertError } = await supabaseAdmin
      .from('invite_codes')
      .insert({
        wedding_id: membership.wedding_id,
        code: inviteCode,
        created_by: user.id,
        role: role,
        is_used: false
      })
      .select()
      .single();

    if (insertError) {
      console.error('Failed to create invite:', insertError);
      return res.status(500).json({
        error: 'Failed to create invite code'
      });
    }

    // ========================================================================
    // STEP 5: Return success response
    // ========================================================================
    return res.status(200).json({
      success: true,
      inviteCode: invite.code,
      role: invite.role,
      weddingId: invite.wedding_id,
      message: `${role === 'bestie' ? 'Bestie' : 'Co-planner'} invite created successfully`
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

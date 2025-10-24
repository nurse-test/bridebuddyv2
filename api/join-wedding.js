// ============================================================================
// JOIN WEDDING - VERCEL FUNCTION (DIRECT IMPLEMENTATION)
// ============================================================================
// Allows users to join a wedding using an invite code
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

  const { inviteCode, userToken } = req.body;

  // Validate input
  if (!inviteCode || !userToken) {
    return res.status(400).json({
      error: 'Missing required fields: inviteCode and userToken'
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
    // STEP 2: Look up the invite code
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
    // STEP 3: Check if user is already a member of this wedding
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
    // STEP 4: Add user to the wedding with role from invite
    // ========================================================================
    const { data: newMember, error: addMemberError } = await supabaseAdmin
      .from('wedding_members')
      .insert({
        wedding_id: invite.wedding_id,
        user_id: user.id,
        role: invite.role  // 'member' or 'bestie'
      })
      .select()
      .single();

    if (addMemberError) {
      console.error('Failed to add member:', addMemberError);
      return res.status(500).json({
        error: 'Failed to join wedding'
      });
    }

    // ========================================================================
    // STEP 5: Mark invite code as used
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
    // STEP 6: Fetch wedding details for response
    // ========================================================================
    const { data: wedding, error: weddingError } = await supabaseAdmin
      .from('wedding_profiles')
      .select('wedding_name, wedding_date')
      .eq('id', invite.wedding_id)
      .single();

    // ========================================================================
    // STEP 7: Return success response
    // ========================================================================
    return res.status(200).json({
      success: true,
      weddingId: invite.wedding_id,
      role: invite.role,
      weddingName: wedding?.wedding_name || null,
      weddingDate: wedding?.wedding_date || null,
      message: `Successfully joined as ${invite.role === 'bestie' ? 'Bestie' : 'Co-planner'}`
    });

  } catch (error) {
    console.error('Join wedding error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
}

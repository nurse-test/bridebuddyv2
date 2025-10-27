// ============================================================================
// GET MY BESTIE PERMISSIONS - VERCEL FUNCTION
// ============================================================================
// Purpose: Bestie views their inviter's access to their knowledge
// Part of: Phase 2 - Bestie Permission System API Endpoints
// ============================================================================

import { createClient } from '@supabase/supabase-js';

// Service role client (bypasses RLS for admin operations)
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { userToken, wedding_id } = req.query;

  // ============================================================================
  // STEP 1: Validate input
  // ============================================================================

  if (!userToken || !wedding_id) {
    return res.status(400).json({
      error: 'Missing required parameters: userToken and wedding_id'
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
    // STEP 3: Verify user is a bestie for this wedding
    // ========================================================================

    const { data: membership, error: membershipError } = await supabaseAdmin
      .from('wedding_members')
      .select('role, invited_by_user_id, wedding_profile_permissions')
      .eq('user_id', user.id)
      .eq('wedding_id', wedding_id)
      .single();

    if (membershipError || !membership) {
      return res.status(404).json({
        error: 'You are not a member of this wedding'
      });
    }

    if (membership.role !== 'bestie') {
      return res.status(403).json({
        error: 'Only besties can view bestie permissions. This endpoint is for MOH/Best Man only.'
      });
    }

    if (!membership.invited_by_user_id) {
      return res.status(500).json({
        error: 'Your bestie relationship is not properly configured (missing invited_by). Please contact support.'
      });
    }

    // ========================================================================
    // STEP 4: Get bestie's permission record
    // ========================================================================

    const { data: permissions, error: permissionsError } = await supabaseAdmin
      .from('bestie_permissions')
      .select('*')
      .eq('bestie_user_id', user.id)
      .eq('wedding_id', wedding_id)
      .single();

    if (permissionsError || !permissions) {
      return res.status(404).json({
        error: 'Bestie permissions record not found. This may indicate a setup issue.'
      });
    }

    // ========================================================================
    // STEP 5: Get inviter's profile info
    // ========================================================================

    const { data: inviter, error: inviterError } = await supabaseAdmin
      .from('profiles')
      .select('full_name, email')
      .eq('id', membership.invited_by_user_id)
      .single();

    // ========================================================================
    // STEP 6: Get wedding info
    // ========================================================================

    const { data: wedding, error: weddingError } = await supabaseAdmin
      .from('wedding_profiles')
      .select('wedding_name, wedding_date')
      .eq('id', wedding_id)
      .single();

    // ========================================================================
    // STEP 7: Get knowledge stats
    // ========================================================================

    const { data: knowledgeStats, error: statsError } = await supabaseAdmin
      .from('bestie_knowledge')
      .select('id, is_private')
      .eq('bestie_user_id', user.id)
      .eq('wedding_id', wedding_id);

    const totalKnowledge = knowledgeStats?.length || 0;
    const privateKnowledge = knowledgeStats?.filter(k => k.is_private).length || 0;
    const sharedKnowledge = totalKnowledge - privateKnowledge;

    // ========================================================================
    // STEP 8: Return comprehensive permission status
    // ========================================================================

    return res.status(200).json({
      success: true,
      bestie: {
        userId: user.id,
        email: user.email
      },
      inviter: {
        userId: membership.invited_by_user_id,
        name: inviter?.full_name || 'Unknown',
        email: inviter?.email || 'Unknown'
      },
      wedding: {
        id: wedding_id,
        name: wedding?.wedding_name || 'Unknown',
        date: wedding?.wedding_date || null
      },
      permissions: {
        // What access the inviter has to YOUR knowledge
        inviterCanReadMyKnowledge: permissions.permissions.can_read || false,
        inviterCanEditMyKnowledge: permissions.permissions.can_edit || false,

        // What access YOU have to the wedding profile
        youCanReadWeddingProfile: membership.wedding_profile_permissions?.can_read || false,
        youCanEditWeddingProfile: membership.wedding_profile_permissions?.can_edit || false
      },
      knowledgeStats: {
        totalItems: totalKnowledge,
        privateItems: privateKnowledge,
        sharedWithInviter: sharedKnowledge,
        visibleToInviter: permissions.permissions.can_read ? sharedKnowledge : 0,
        editableByInviter: permissions.permissions.can_edit ? sharedKnowledge : 0
      },
      explanation: {
        canRead: permissions.permissions.can_read
          ? `${inviter?.full_name || 'Your inviter'} can view your non-private bestie knowledge (${sharedKnowledge} items)`
          : `${inviter?.full_name || 'Your inviter'} cannot view your bestie knowledge`,
        canEdit: permissions.permissions.can_edit
          ? `${inviter?.full_name || 'Your inviter'} can edit your non-private bestie knowledge (${sharedKnowledge} items)`
          : `${inviter?.full_name || 'Your inviter'} cannot edit your bestie knowledge`,
        privateNote: privateKnowledge > 0
          ? `You have ${privateKnowledge} private items that are always hidden, regardless of permissions`
          : 'You have no private items'
      },
      lastUpdated: permissions.updated_at
    });

  } catch (error) {
    console.error('Get bestie permissions error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
}

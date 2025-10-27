// ============================================================================
// UPDATE MY INVITER ACCESS - VERCEL FUNCTION
// ============================================================================
// Purpose: Bestie updates what access their inviter has to bestie knowledge
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

  const { userToken, wedding_id, can_read, can_edit } = req.body;

  // ============================================================================
  // STEP 1: Validate input
  // ============================================================================

  if (!userToken || !wedding_id) {
    return res.status(400).json({
      error: 'Missing required fields: userToken and wedding_id'
    });
  }

  if (typeof can_read !== 'boolean' || typeof can_edit !== 'boolean') {
    return res.status(400).json({
      error: 'Invalid permission values. can_read and can_edit must be boolean (true/false)'
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
      .select('role, invited_by_user_id')
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
        error: 'Only besties can manage inviter permissions'
      });
    }

    if (!membership.invited_by_user_id) {
      return res.status(500).json({
        error: 'Your bestie relationship is not properly configured (missing invited_by). Please contact support.'
      });
    }

    // ========================================================================
    // STEP 4: Get current permission record
    // ========================================================================

    const { data: currentPermissions, error: getCurrentError } = await supabaseAdmin
      .from('bestie_permissions')
      .select('*')
      .eq('bestie_user_id', user.id)
      .eq('wedding_id', wedding_id)
      .single();

    if (getCurrentError || !currentPermissions) {
      return res.status(404).json({
        error: 'Bestie permissions record not found. This may indicate a setup issue.'
      });
    }

    // ========================================================================
    // STEP 5: Validate permission logic
    // ========================================================================

    // If granting edit access, must also grant read access
    if (can_edit && !can_read) {
      return res.status(400).json({
        error: 'Invalid permission combination: cannot grant edit access without read access',
        suggestion: 'Set both can_read=true and can_edit=true to grant edit access'
      });
    }

    // ========================================================================
    // STEP 6: Update ONLY the bestie's own permission record
    // ========================================================================
    // RLS policies ensure bestie can only update their own record

    const { data: updated, error: updateError } = await supabaseAdmin
      .from('bestie_permissions')
      .update({
        permissions: { can_read, can_edit },
        updated_at: new Date().toISOString()
      })
      .eq('bestie_user_id', user.id)  // Can only update own record
      .eq('wedding_id', wedding_id)
      .select()
      .single();

    if (updateError) {
      console.error('Failed to update bestie permissions:', updateError);
      return res.status(500).json({
        error: 'Failed to update permissions',
        details: updateError.message
      });
    }

    // ========================================================================
    // STEP 7: Get inviter details for response
    // ========================================================================

    const { data: inviter, error: inviterError } = await supabaseAdmin
      .from('profiles')
      .select('full_name, email')
      .eq('id', membership.invited_by_user_id)
      .single();

    // ========================================================================
    // STEP 8: Get knowledge stats to show impact
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
    // STEP 9: Return success response with impact summary
    // ========================================================================

    return res.status(200).json({
      success: true,
      message: 'Inviter permissions updated successfully',
      inviter: {
        userId: membership.invited_by_user_id,
        name: inviter?.full_name || 'Unknown',
        email: inviter?.email || 'Unknown'
      },
      updatedPermissions: {
        can_read: can_read,
        can_edit: can_edit
      },
      impact: {
        totalKnowledgeItems: totalKnowledge,
        privateItems: privateKnowledge,
        sharedItems: sharedKnowledge,
        nowVisibleToInviter: can_read ? sharedKnowledge : 0,
        nowEditableByInviter: can_edit ? sharedKnowledge : 0
      },
      explanation: {
        canRead: can_read
          ? `✅ ${inviter?.full_name || 'Your inviter'} can now VIEW ${sharedKnowledge} non-private items in your bestie knowledge`
          : `🔒 ${inviter?.full_name || 'Your inviter'} cannot view your bestie knowledge`,
        canEdit: can_edit
          ? `✅ ${inviter?.full_name || 'Your inviter'} can now EDIT ${sharedKnowledge} non-private items in your bestie knowledge`
          : `🔒 ${inviter?.full_name || 'Your inviter'} cannot edit your bestie knowledge`,
        privateNote: privateKnowledge > 0
          ? `🔐 ${privateKnowledge} private items remain hidden regardless of permissions (for surprise planning)`
          : null
      },
      nextSteps: can_read
        ? [
            'Your inviter can now see your bestie planning',
            'They can help with coordination and logistics',
            privateKnowledge > 0 ? 'Your private items remain hidden for surprises' : null,
            can_edit ? 'They can also edit and update your plans' : 'They can view but not edit (read-only access)'
          ].filter(Boolean)
        : [
            'Your inviter cannot access your bestie knowledge',
            'You maintain complete privacy for surprise planning',
            'You can grant access anytime via this endpoint'
          ],
      updatedAt: updated.updated_at
    });

  } catch (error) {
    console.error('Update inviter access error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
}

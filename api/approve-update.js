import { createClient } from '@supabase/supabase-js';
import { handleCORS, rateLimitMiddleware, RATE_LIMITS } from './_utils/rate-limiter.js';

const supabase = createClient(
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

  const { userToken, updateId, approve } = req.body;

  if (!userToken || !updateId || approve === undefined) {
    return res.status(400).json({ error: 'User token, update ID, and approve status required' });
  }

  // Create client with user token for auth
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

  try {
    // Verify user
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser();
    if (userError || !user) throw new Error('Invalid user token');

    // Get the pending update
    const { data: update, error: updateError } = await supabase
      .from('pending_updates')
      .select('*')
      .eq('id', updateId)
      .single();

    if (updateError || !update) {
      throw new Error('Update not found');
    }

    // Verify user has access to this wedding and has owner/partner role
    const { data: membership, error: memberError } = await supabaseUser
      .from('wedding_members')
      .select('wedding_id, role')
      .eq('user_id', user.id)
      .eq('wedding_id', update.wedding_id)
      .single();

    if (memberError || !membership) {
      throw new Error('You do not have access to this wedding');
    }

    // Only owners and partners can approve/reject updates
    if (membership.role !== 'owner' && membership.role !== 'partner') {
      return res.status(403).json({
        error: 'Only wedding owners and partners can approve or reject updates. Besties cannot manage approvals.'
      });
    }

    if (approve) {
      // Apply the update to the wedding profile
      const updateData = {};
      updateData[update.field_name] = update.new_value;

      const { error: applyError } = await supabase
        .from('wedding_profiles')
        .update(updateData)
        .eq('id', update.wedding_id);

      if (applyError) {
        throw new Error('Failed to apply update: ' + applyError.message);
      }

      // Mark as approved
      await supabase
        .from('pending_updates')
        .update({ status: 'approved' })
        .eq('id', updateId);

      return res.status(200).json({
        success: true,
        message: 'Update approved and applied'
      });

    } else {
      // Mark as rejected
      await supabase
        .from('pending_updates')
        .update({ status: 'rejected' })
        .eq('id', updateId);

      return res.status(200).json({
        success: true,
        message: 'Update rejected'
      });
    }

  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: error.message });
  }
}

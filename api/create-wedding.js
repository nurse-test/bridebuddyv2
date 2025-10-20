import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { userId, coupleNames, weddingDate } = req.body;

  if (!userId) {
    return res.status(400).json({ error: 'User ID required' });
  }

  try {
    // Check if user already has a wedding
    const { data: existingMembership } = await supabase
      .from('wedding_members')
      .select('wedding_id')
      .eq('user_id', userId)
      .eq('role', 'owner')
      .single();

    if (existingMembership) {
      return res.status(400).json({ error: 'User already has a wedding' });
    }

    // Create wedding profile
    const { data: wedding, error: weddingError } = await supabase
      .from('wedding_profiles')
      .insert({
        owner_id: userId,
        wedding_name: coupleNames,
        wedding_date: weddingDate,
        trial_start_date: new Date().toISOString(),
        trial_end_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(), // 14 day trial
        plan_type: 'trial'
      })
      .select()
      .single();

    if (weddingError) {
      console.error('Wedding creation error:', weddingError);
      return res.status(500).json({ error: weddingError.message });
    }

    // Add owner to wedding_members
    const { error: memberError } = await supabase
      .from('wedding_members')
      .insert({
        wedding_id: wedding.id,
        user_id: userId,
        role: 'owner'
      });

    if (memberError) {
      console.error('Member creation error:', memberError);
      return res.status(500).json({ error: memberError.message });
    }

    return res.status(200).json({ 
      success: true, 
      weddingId: wedding.id 
    });
  } catch (error) {
    console.error('Unexpected error:', error);
    return res.status(500).json({ error: error.message });
  }
}

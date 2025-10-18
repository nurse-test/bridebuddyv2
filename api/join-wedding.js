import { createClient } from '@supabase/supabase-js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { inviteCode, userToken } = req.body;

  if (!inviteCode || !userToken) {
    return res.status(400).json({ error: 'Invite code and user token required' });
  }

  const supabase = createClient(
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
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) throw new Error('Invalid user token');

    // Find wedding by invite code
    const { data: wedding, error: weddingError } = await supabase
      .from('wedding_profiles')
      .select('id, couple_names')
      .eq('invite_code', inviteCode)
      .single();

    if (weddingError || !wedding) {
      return res.status(404).json({ error: 'Invalid invite code' });
    }

    // Check if user is already a member
    const { data: existing } = await supabase
      .from('wedding_members')
      .select('id')
      .eq('wedding_id', wedding.id)
      .eq('user_id', user.id)
      .single();

    if (existing) {
      return res.status(200).json({ 
        message: 'Already a member',
        weddingId: wedding.id
      });
    }

    // Add user as co-planner
    const { error: memberError } = await supabase
      .from('wedding_members')
      .insert({
        wedding_id: wedding.id,
        user_id: user.id,
        role: 'co-planner'
      });

    if (memberError) throw memberError;

    return res.status(200).json({ 
      message: 'Successfully joined wedding!',
      weddingId: wedding.id,
      coupleName: wedding.couple_names
    });
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: error.message });
  }
}

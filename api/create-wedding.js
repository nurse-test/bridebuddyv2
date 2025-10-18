import { createClient } from '@supabase/supabase-js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { userToken, coupleNames, weddingDate } = req.body;

  if (!userToken || !coupleNames) {
    return res.status(400).json({ error: 'User token and couple names required' });
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

    // Check if user already has a wedding profile
    const { data: existingMembership } = await supabase
      .from('wedding_members')
      .select('wedding_id')
      .eq('user_id', user.id)
      .single();

    if (existingMembership) {
      return res.status(200).json({ 
        weddingId: existingMembership.wedding_id,
        message: 'Wedding profile already exists'
      });
    }

    // Create wedding profile
    const { data: wedding, error: weddingError } = await supabase
      .from('wedding_profiles')
      .insert({
        owner_id: user.id,
        couple_names: coupleNames,
        wedding_date: weddingDate
      })
      .select()
      .single();

    if (weddingError) throw weddingError;

    // Add user as owner in wedding_members
    const { error: memberError } = await supabase
      .from('wedding_members')
      .insert({
        wedding_id: wedding.id,
        user_id: user.id,
        role: 'owner'
      });

    if (memberError) throw memberError;

    return res.status(200).json({ 
      weddingId: wedding.id,
      message: 'Wedding profile created successfully'
    });
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: error.message });
  }
}

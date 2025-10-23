import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const {
    userId,
    coupleNames,
    weddingDate,
    partner1Name,
    partner2Name,
    weddingTime,
    ceremonyLocation,
    receptionLocation,
    expectedGuestCount,
    totalBudget,
    weddingStyle,
    colorSchemePrimary
  } = req.body;

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

    // Build wedding profile data
    const weddingData = {
      owner_id: userId,
      trial_start_date: new Date().toISOString(),
      trial_end_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(), // 14 day trial
      plan_type: 'trial',
      subscription_status: 'trialing',
      bestie_addon_enabled: true  // Include 1 bestie invite in free trial
    };

    // Add optional fields
    if (coupleNames) weddingData.wedding_name = coupleNames;
    if (weddingDate) weddingData.wedding_date = weddingDate;
    if (partner1Name) weddingData.partner1_name = partner1Name;
    if (partner2Name) weddingData.partner2_name = partner2Name;
    if (weddingTime) weddingData.wedding_time = weddingTime;
    if (ceremonyLocation) weddingData.ceremony_location = ceremonyLocation;
    if (receptionLocation) weddingData.reception_location = receptionLocation;
    if (expectedGuestCount) weddingData.expected_guest_count = parseInt(expectedGuestCount);
    if (totalBudget) weddingData.total_budget = parseFloat(totalBudget);
    if (weddingStyle) weddingData.wedding_style = weddingStyle;
    if (colorSchemePrimary) weddingData.color_scheme_primary = colorSchemePrimary;

    // Create wedding profile
    const { data: wedding, error: weddingError } = await supabase
      .from('wedding_profiles')
      .insert(weddingData)
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

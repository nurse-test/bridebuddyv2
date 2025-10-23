import { createClient } from '@supabase/supabase-js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { message, conversationId, userToken } = req.body;

  if (!message || !userToken) {
    return res.status(400).json({ error: 'Message and user token required' });
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

  // Service role client for database updates
  const supabaseService = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );

  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) throw new Error('Invalid user token');

    // Get user's wedding
    const { data: membership, error: memberError } = await supabase
      .from('wedding_members')
      .select('wedding_id')
      .eq('user_id', user.id)
      .single();

    if (memberError || !membership) throw new Error('No wedding profile found');

    const { data: weddingData, error: weddingError } = await supabase
      .from('wedding_profiles')
      .select('*')
      .eq('id', membership.wedding_id)
      .single();

    if (weddingError || !weddingData) throw new Error('Wedding profile not found');

    // Check trial/VIP status
    const now = new Date();
    const trialEnds = weddingData.trial_end_date ? new Date(weddingData.trial_end_date) : null;
    const isVip = weddingData.is_vip;
    const daysLeft = trialEnds ? Math.ceil((trialEnds - now) / (1000 * 60 * 60 * 24)) : null;

    if (trialEnds && now > trialEnds && !isVip) {
      return res.status(200).json({
        response: "Your trial has ended! 🎉\n\nUpgrade to VIP to continue:\n✨ Unlimited messages\n✨ Full wedding database\n✨ Co-planner access\n\nChoose your plan:\n💍 $19.99/month\n💒 $199 one-time 'Until I Do'\n\nHead to the upgrade page to continue planning!",
        trialExpired: true
      });
    }

    let trialWarning = '';
    if (trialEnds && daysLeft <= 2 && daysLeft > 0 && !isVip) {
      trialWarning = `\n\n⏰ Reminder: Your trial ends in ${daysLeft} day${daysLeft === 1 ? '' : 's'}! Upgrade to keep unlimited access.`;
    }

    // Build wedding context
    let weddingContext = `You are Bride Buddy, a helpful wedding planning assistant.

CURRENT WEDDING INFORMATION:`;
    if (weddingData.wedding_name) weddingContext += `\n- Couple: ${weddingData.wedding_name}`;
    if (weddingData.partner1_name && weddingData.partner2_name) {
      weddingContext += `\n- Partners: ${weddingData.partner1_name} & ${weddingData.partner2_name}`;
    }
    if (weddingData.wedding_date) weddingContext += `\n- Wedding Date: ${weddingData.wedding_date}`;
    if (weddingData.wedding_time) weddingContext += `\n- Time: ${weddingData.wedding_time}`;
    if (weddingData.ceremony_location) weddingContext += `\n- Ceremony: ${weddingData.ceremony_location}`;
    if (weddingData.reception_location) weddingContext += `\n- Reception: ${weddingData.reception_location}`;
    if (weddingData.expected_guest_count) weddingContext += `\n- Expected Guests: ${weddingData.expected_guest_count}`;
    if (weddingData.total_budget) weddingContext += `\n- Total Budget: $${weddingData.total_budget}`;
    if (weddingData.wedding_style) weddingContext += `\n- Style: ${weddingData.wedding_style}`;
    if (weddingData.color_scheme_primary) weddingContext += `\n- Primary Color: ${weddingData.color_scheme_primary}`;
    if (weddingData.venue_name) weddingContext += `\n- Venue: ${weddingData.venue_name}${weddingData.venue_cost ? ` ($${weddingData.venue_cost})` : ''}`;

    // CALL CLAUDE with extraction prompt
    const claudeResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 2048,
        messages: [{
          role: 'user',
          content: `${weddingContext}

TASK: Extract wedding information from the user's message and respond naturally.

USER MESSAGE: "${message}"

INSTRUCTIONS:
1. Respond warmly and helpfully to the user
2. If the message contains ANY wedding details (dates, venues, colors, budget, vendors, names, guest count, etc.), extract them
3. Return your response in this EXACT format:

<response>Your natural, conversational response here</response>

<extracted_data>
{
  "wedding_date": "YYYY-MM-DD or null",
  "wedding_time": "HH:MM or null",
  "partner1_name": "string or null",
  "partner2_name": "string or null",
  "ceremony_location": "string or null",
  "reception_location": "string or null",
  "venue_name": "string or null",
  "venue_cost": number or null,
  "expected_guest_count": number or null,
  "total_budget": number or null,
  "color_scheme_primary": "string or null",
  "color_scheme_secondary": "string or null",
  "wedding_style": "string or null",
  "photographer_name": "string or null",
  "photographer_cost": number or null,
  "caterer_name": "string or null",
  "caterer_cost": number or null",
  "florist_name": "string or null",
  "florist_cost": number or null",
  "dj_band_name": "string or null",
  "dj_band_cost": number or null",
  "baker_name": "string or null",
  "cake_flavors": "string or null"
}
</extracted_data>

ONLY include fields that were mentioned in the message. If nothing was mentioned, return empty JSON: {}`
        }]
      })
    });

    // Check if API call was successful
    if (!claudeResponse.ok) {
      const errorData = await claudeResponse.json();
      console.error('Anthropic API error:', errorData);
      console.error('API key present:', !!process.env.ANTHROPIC_API_KEY);
      console.error('API key length:', process.env.ANTHROPIC_API_KEY?.length || 0);
      throw new Error(`Anthropic API error: ${errorData.error?.message || 'Unknown error'}`);
    }

    const claudeData = await claudeResponse.json();

    if (!claudeData.content || !claudeData.content[0]) {
      throw new Error('Invalid response from Claude');
    }

    const fullResponse = claudeData.content[0].text;

    // Parse response and extracted data
    const responseMatch = fullResponse.match(/<response>([\s\S]*?)<\/response>/);
    const dataMatch = fullResponse.match(/<extracted_data>([\s\S]*?)<\/extracted_data>/);

    let assistantMessage = responseMatch ? responseMatch[1].trim() : fullResponse;
    let extractedData = {};

    if (dataMatch) {
      try {
        const jsonStr = dataMatch[1].trim();
        extractedData = JSON.parse(jsonStr);
      } catch (e) {
        console.error('Failed to parse extracted data:', e);
      }
    }

    // Update database with extracted data
    if (Object.keys(extractedData).length > 0) {
      const updates = {};
      
      // Only include non-null values
      Object.keys(extractedData).forEach(key => {
        if (extractedData[key] !== null && extractedData[key] !== undefined) {
          updates[key] = extractedData[key];
        }
      });

      if (Object.keys(updates).length > 0) {
        const { error: updateError } = await supabaseService
          .from('wedding_profiles')
          .update(updates)
          .eq('id', membership.wedding_id);

        if (updateError) {
          console.error('Failed to update wedding profile:', updateError);
        } else {
          console.log('Successfully updated wedding profile with:', updates);
        }
      }
    }

    assistantMessage += trialWarning;

    return res.status(200).json({ 
      response: assistantMessage,
      conversationId: conversationId || 'temp',
      daysLeftInTrial: daysLeft,
      extractedData: extractedData // For debugging
    });

  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: error.message });
  }
}

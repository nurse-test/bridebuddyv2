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

  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) throw new Error('Invalid user token');

    // Get user's wedding with trial info
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

    // If trial expired and not VIP, show upgrade message
    if (trialEnds && now > trialEnds && !isVip) {
      return res.status(200).json({
        response: "Your trial has ended! 🎉\n\nUpgrade to VIP to continue:\n✨ Unlimited messages\n✨ Full wedding database\n✨ Co-planner access\n\nChoose your plan:\n💍 $9.99/month\n💒 $99 one-time 'Until I Do'\n\nHead to the upgrade page to continue planning!",
        trialExpired: true
      });
    }

    // If trial ending soon (2 days or less), add reminder
    let trialWarning = '';
    if (trialEnds && daysLeft <= 2 && daysLeft > 0 && !isVip) {
      trialWarning = `\n\n⏰ Reminder: Your trial ends in ${daysLeft} day${daysLeft === 1 ? '' : 's'}! Upgrade to keep unlimited access.`;
    }

    // Build wedding context from NEW database structure
    let weddingContext = `You are Bride Buddy, a helpful wedding planning assistant.`;
    if (weddingData.wedding_name) weddingContext += `\nCouple: ${weddingData.wedding_name}`;
    if (weddingData.partner1_name && weddingData.partner2_name) {
      weddingContext += `\nPartners: ${weddingData.partner1_name} & ${weddingData.partner2_name}`;
    }
    if (weddingData.wedding_date) weddingContext += `\nWedding Date: ${weddingData.wedding_date}`;
    if (weddingData.expected_guest_count) weddingContext += `\nExpected Guests: ${weddingData.expected_guest_count}`;
    if (weddingData.total_budget) weddingContext += `\nTotal Budget: $${weddingData.total_budget}`;
    if (weddingData.wedding_style) weddingContext += `\nStyle: ${weddingData.wedding_style}`;
    if (weddingData.color_scheme_primary) weddingContext += `\nColors: ${weddingData.color_scheme_primary}`;

    // Call Claude API
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 1024,
        messages: [{
          role: 'user',
          content: `${weddingContext}\n\nBe warm, enthusiastic, and practical. Keep responses concise but helpful.\n\nUser question: ${message}`
        }]
      })
    });

    const data = await response.json();

    if (data.content && data.content[0]) {
      let assistantMessage = data.content[0].text + trialWarning;

      return res.status(200).json({ 
        response: assistantMessage,
        conversationId: conversationId || 'temp',
        daysLeftInTrial: daysLeft
      });
    } else {
      return res.status(500).json({ error: 'Invalid response from Claude' });
    }
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: error.message });
  }
}

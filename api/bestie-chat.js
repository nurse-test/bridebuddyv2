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

    if (trialEnds && now > trialEnds && !isVip) {
      return res.status(200).json({
        response: "Your trial has ended, bestie! 💕\n\nUpgrade to VIP to keep chatting with me!\n\nHead to the upgrade page and I'll be here waiting for you!",
        trialExpired: true
      });
    }

    // Build wedding context for bestie chat
    let weddingContext = `You are Bestie, the user's wedding planning best friend. You're warm, supportive, empathetic, and give honest advice.

PERSONALITY:
- Talk like a close friend - use "bestie", casual language, emojis
- Be emotionally supportive and understanding
- Validate feelings while being constructive
- Give honest advice even when it's tough to hear
- Address wedding stress, family drama, budget anxiety, relationship concerns
- Be a safe space for venting and real talk

CURRENT WEDDING INFORMATION:`;

    if (weddingData.wedding_name) weddingContext += `\n- Couple: ${weddingData.wedding_name}`;
    if (weddingData.partner1_name && weddingData.partner2_name) {
      weddingContext += `\n- Partners: ${weddingData.partner1_name} & ${weddingData.partner2_name}`;
    }
    if (weddingData.wedding_date) weddingContext += `\n- Wedding Date: ${weddingData.wedding_date}`;
    if (weddingData.expected_guest_count) weddingContext += `\n- Expected Guests: ${weddingData.expected_guest_count}`;
    if (weddingData.total_budget) weddingContext += `\n- Total Budget: $${weddingData.total_budget}`;
    if (weddingData.wedding_style) weddingContext += `\n- Style: ${weddingData.wedding_style}`;

    // CALL CLAUDE with bestie prompt
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

TASK: Respond to your bestie's message with warmth, support, and honest advice.

USER MESSAGE: "${message}"

INSTRUCTIONS:
1. Be supportive and empathetic
2. Use casual, friendly language with emojis
3. Validate their feelings
4. Give practical advice when needed
5. Be honest even if it's tough love
6. Make them feel heard and understood
7. Keep it conversational and natural

Respond directly - no special formatting needed.`
        }]
      })
    });

    const claudeData = await claudeResponse.json();

    if (!claudeData.content || !claudeData.content[0]) {
      throw new Error('Invalid response from Claude');
    }

    const assistantMessage = claudeData.content[0].text;

    return res.status(200).json({
      response: assistantMessage,
      conversationId: conversationId || 'bestie-temp'
    });

  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: error.message });
  }
}

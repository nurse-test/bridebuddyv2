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

    if (trialEnds && now > trialEnds && !isVip) {
      return res.status(200).json({
        response: "Your trial has ended, bestie! 💕\n\nUpgrade to VIP to keep chatting with me!\n\nHead to the upgrade page and I'll be here waiting for you!",
        trialExpired: true
      });
    }

    // Build wedding context for bestie chat
    let weddingContext = `You are Bestie Buddy, the AI assistant for the Maid of Honor, Best Man, or Best Friend helping plan wedding events.

YOUR ROLE:
- Help the MOH/Best Man plan bachelorette/bachelor parties
- Assist with bridal shower planning
- Guide engagement party coordination
- Help manage bridesmaids/groomsmen logistics
- Track bridesmaid expenses and dress shopping
- Coordinate rehearsal dinner planning
- Provide advice on MOH/Best Man duties and etiquette

PERSONALITY:
- Friendly, practical, and organized
- Understanding of the unique pressures of being MOH/Best Man
- Budget-conscious and creative with party planning
- Supportive when dealing with difficult bridesmaids or family
- Use casual language but stay focused on actionable advice

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

TASK: Help the Maid of Honor/Best Man with their wedding planning duties and event coordination.

USER MESSAGE: "${message}"

INSTRUCTIONS:
1. Provide practical, actionable advice for MOH/Best Man responsibilities
2. Help plan bachelorette parties, bridal showers, and engagement parties
3. Assist with bridesmaids/groomsmen coordination and logistics
4. Give budget-friendly ideas and creative solutions
5. Address common MOH/Best Man challenges (difficult bridesmaids, expenses, time management)
6. Offer timeline recommendations and checklists when relevant
7. Be supportive but focused on getting things done
8. Use friendly, casual language but stay organized and practical

Respond directly with helpful advice and actionable next steps.`
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

    const assistantMessage = claudeData.content[0].text;

    // Save messages to chat_messages table
    try {
      // Save user message
      const { error: userMsgError } = await supabaseService
        .from('chat_messages')
        .insert({
          wedding_id: membership.wedding_id,
          user_id: user.id,
          role: 'user',
          message: message,
          message_type: 'bestie'
        });

      if (userMsgError) {
        console.error('Failed to save user message:', userMsgError);
      }

      // Save assistant message
      const { error: assistantMsgError } = await supabaseService
        .from('chat_messages')
        .insert({
          wedding_id: membership.wedding_id,
          user_id: user.id,
          role: 'assistant',
          message: assistantMessage,
          message_type: 'bestie'
        });

      if (assistantMsgError) {
        console.error('Failed to save assistant message:', assistantMsgError);
      }
    } catch (saveError) {
      console.error('Error saving chat messages:', saveError);
      // Don't fail the request if saving fails
    }

    return res.status(200).json({
      response: assistantMessage,
      conversationId: conversationId || 'bestie-temp'
    });

  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: error.message });
  }
}

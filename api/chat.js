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
      .select('wedding_id, wedding_profiles(*)')
      .eq('user_id', user.id)
      .single();

    if (memberError || !membership) throw new Error('No wedding profile found');

    const weddingId = membership.wedding_id;
    const weddingData = membership.wedding_profiles;

    // Check trial status
    const now = new Date();
    const trialEnds = weddingData.trial_ends_at ? new Date(weddingData.trial_ends_at) : null;
    const isVip = weddingData.is_vip;
    const daysLeft = trialEnds ? Math.ceil((trialEnds - now) / (1000 * 60 * 60 * 24)) : null;

    // If trial expired and not VIP, show upgrade message
    if (trialEnds && now > trialEnds && !isVip) {
      return res.status(200).json({
        response: "Your 7-day VIP trial has ended! 🎉\n\nYou're now on the Basic plan (20 messages/day with no saved data).\n\nUpgrade to VIP to get:\n✨ Unlimited messages\n✨ Full wedding database\n✨ Conversation history\n✨ Co-planner access\n\nChoose your plan:\n💍 $29.99/month\n💒 $349 one-time 'Until I Do'\n\n[Upgrade Now](#upgrade)",
        trialExpired: true
      });
    }

    // If trial ending soon (2 days or less), add reminder
    let trialWarning = '';
    if (trialEnds && daysLeft <= 2 && daysLeft > 0 && !isVip) {
      trialWarning = `\n\n⏰ Reminder: Your VIP trial ends in ${daysLeft} day${daysLeft === 1 ? '' : 's'}! Upgrade to keep unlimited access.`;
    }

    // If no conversationId, create new conversation
    let currentConversationId = conversationId;
    if (!currentConversationId) {
      const { data: newConversation, error: convError } = await supabase
        .from('conversations')
        .insert({ 
          wedding_id: weddingId, 
          title: message.substring(0, 50) 
        })
        .select()
        .single();
      
      if (convError) throw convError;
      currentConversationId = newConversation.id;
    }

    // Save user message
    await supabase.from('messages').insert({
      conversation_id: currentConversationId,
      role: 'user',
      content: message
    });

    // Build wedding context
    let weddingContext = `You are Bride Buddy, helping plan a wedding.`;
    if (weddingData.couple_names) weddingContext += `\nCouple: ${weddingData.couple_names}`;
    if (weddingData.wedding_date) weddingContext += `\nWedding Date: ${weddingData.wedding_date}`;
    if (weddingData.guest_count) weddingContext += `\nGuest Count: ${weddingData.guest_count}`;
    if (weddingData.budget) weddingContext += `\nBudget: $${weddingData.budget}`;

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
      
      // Save assistant message
      await supabase.from('messages').insert({
        conversation_id: currentConversationId,
        role: 'assistant',
        content: assistantMessage
      });

      return res.status(200).json({ 
        response: assistantMessage,
        conversationId: currentConversationId,
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

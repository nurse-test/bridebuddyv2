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
      .select('wedding_id, wedding_profiles(*)')
      .eq('user_id', user.id)
      .single();

    if (memberError || !membership) throw new Error('No wedding profile found');

    const weddingId = membership.wedding_id;
    const weddingData = membership.wedding_profiles;

    // If no conversationId, create a new conversation
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

    // Build context about the wedding
    let weddingContext = `You are Bride Buddy, helping plan a wedding.`;
    if (weddingData.couple_names) weddingContext += `\nCouple: ${weddingData.couple_names}`;
    if (weddingData.wedding_date) weddingContext += `\nWedding Date: ${weddingData.wedding_date}`;
    if (weddingData.guest_count) weddingContext += `\nGuest Count: ${weddingData.guest_count}`;
    if (weddingData.budget) weddingContext += `\nBudget: $${weddingData.budget}`;
    if (weddingData.venue) weddingContext += `\nVenue: ${weddingData.venue}`;

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
      const assistantMessage = data.content[0].text;
      
      // Save assistant message
      await supabase.from('messages').insert({
        conversation_id: currentConversationId,
        role: 'assistant',
        content: assistantMessage
      });

      return res.status(200).json({ 
        response: assistantMessage,
        conversationId: currentConversationId
      });
    } else {
      return res.status(500).json({ error: 'Invalid response from Claude' });
    }
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: error.message });
  }
}

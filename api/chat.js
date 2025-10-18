import { createClient } from '@supabase/supabase-js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { message, conversationId, userId } = req.body;

  if (!message) {
    return res.status(400).json({ error: 'Message is required' });
  }

  // Initialize Supabase
  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_ANON_KEY
  );

  try {
    // If no conversationId, create a new conversation
    let currentConversationId = conversationId;
    if (!currentConversationId && userId) {
      const { data: newConversation, error: convError } = await supabase
        .from('conversations')
        .insert({ user_id: userId, title: message.substring(0, 50) })
        .select()
        .single();
      
      if (convError) throw convError;
      currentConversationId = newConversation.id;
    }

    // Save user message to database if we have a conversation
    if (currentConversationId) {
      await supabase.from('messages').insert({
        conversation_id: currentConversationId,
        role: 'user',
        content: message
      });
    }

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
          content: `You are Bride Buddy, a helpful wedding planning assistant. Be warm, enthusiastic, and practical. Keep responses concise but helpful.\n\nUser question: ${message}`
        }]
      })
    });

    const data = await response.json();

    if (data.content && data.content[0]) {
      const assistantMessage = data.content[0].text;
      
      // Save assistant message to database if we have a conversation
      if (currentConversationId) {
        await supabase.from('messages').insert({
          conversation_id: currentConversationId,
          role: 'assistant',
          content: assistantMessage
        });
      }

      return res.status(200).json({ 
        response: assistantMessage,
        conversationId: currentConversationId
      });
    } else {
      return res.status(500).json({ error: 'Invalid response from Claude' });
    }
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: 'Failed to get response' });
  }
}

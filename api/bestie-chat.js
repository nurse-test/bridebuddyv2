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

    // Build wedding context for bestie chat with extraction
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

    // CALL CLAUDE with enhanced bestie extraction prompt
    const claudeResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 3072,
        messages: [{
          role: 'user',
          content: `${weddingContext}

TASK: Help the Maid of Honor/Best Man with their wedding planning duties, event coordination, AND extract any structured data.

USER MESSAGE: "${message}"

INSTRUCTIONS:
1. Provide practical, actionable advice for MOH/Best Man responsibilities
2. Help plan bachelorette parties, bridal showers, and engagement parties
3. Extract ANY planning details, budget info, or tasks from the conversation
4. Return your response in this EXACT format:

<response>Your natural, helpful response here</response>

<extracted_data>
{
  "budget_items": [
    {
      "category": "venue|catering|flowers|photography|videography|music|cake|decorations|attire|invitations|favors|transportation|honeymoon|other",
      "budgeted_amount": number or null,
      "spent_amount": number or null,
      "transaction_date": "YYYY-MM-DD or null",
      "transaction_amount": number or null,
      "transaction_description": "string or null",
      "notes": "string or null"
    }
  ],
  "tasks": [
    {
      "task_name": "string",
      "task_description": "string or null",
      "category": "venue|catering|flowers|photography|attire|invitations|decorations|transportation|legal|honeymoon|day_of|other or null",
      "due_date": "YYYY-MM-DD or null",
      "status": "not_started|in_progress|completed|cancelled or null",
      "priority": "low|medium|high|urgent or null",
      "notes": "string or null"
    }
  ]
}
</extracted_data>

EXTRACTION RULES FOR BESTIE CHAT:
- budget_items: Extract mentions of party expenses, bridesmaid costs, event budgets
  * "Spent $300 on bachelorette decorations" → {"category": "decorations", "spent_amount": 300, "transaction_amount": 300, "transaction_date": "today"}
  * "Budgeted $2000 for bridal shower venue" → {"category": "venue", "budgeted_amount": 2000}
  * "Bridesmaids dresses cost $150 each" → {"category": "attire", "transaction_amount": 150, "notes": "per bridesmaid"}
- tasks: Extract to-dos for MOH/Best Man duties, party planning tasks
  * "Need to book venue by next Friday" → {"task_name": "Book venue", "due_date": "[next Friday's date]", "status": "not_started"}
  * "Sent out invitations today!" → {"task_name": "Send bachelorette invitations", "status": "completed"}
  * "Should I send save-the-dates for the bridal shower?" → {"task_name": "Send bridal shower save-the-dates", "status": "not_started", "priority": "medium"}

IMPORTANT:
- Today's date is ${new Date().toISOString().split('T')[0]}
- Focus on extracting MOH/Best Man event planning data (bachelorette, shower, rehearsal dinner, etc.)
- Only include sections that have data. Empty arrays [] are ok if nothing was mentioned
- If nothing actionable was mentioned, return {"budget_items": [], "tasks": []}`
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
    let extractedData = { budget_items: [], tasks: [] };

    if (dataMatch) {
      try {
        const jsonStr = dataMatch[1].trim();
        extractedData = JSON.parse(jsonStr);
      } catch (e) {
        console.error('Failed to parse extracted data:', e);
      }
    }

    // Update database with extracted data from bestie chat
    console.log('Bestie extracted data:', JSON.stringify(extractedData, null, 2));

    // 1. Insert/Update budget items in budget_tracker table
    if (extractedData.budget_items && extractedData.budget_items.length > 0) {
      for (const budgetItem of extractedData.budget_items) {
        // Check if budget category already exists
        const { data: existingBudget } = await supabaseService
          .from('budget_tracker')
          .select('id, spent_amount')
          .eq('wedding_id', membership.wedding_id)
          .eq('category', budgetItem.category)
          .single();

        if (existingBudget) {
          // Update existing budget category
          const budgetUpdates = {};

          if (budgetItem.budgeted_amount !== null && budgetItem.budgeted_amount !== undefined) {
            budgetUpdates.budgeted_amount = budgetItem.budgeted_amount;
          }

          if (budgetItem.spent_amount !== null && budgetItem.spent_amount !== undefined) {
            budgetUpdates.spent_amount = (existingBudget.spent_amount || 0) + budgetItem.spent_amount;
          }

          if (budgetItem.transaction_date) budgetUpdates.last_transaction_date = budgetItem.transaction_date;
          if (budgetItem.transaction_amount) budgetUpdates.last_transaction_amount = budgetItem.transaction_amount;
          if (budgetItem.transaction_description) budgetUpdates.last_transaction_description = budgetItem.transaction_description;
          if (budgetItem.notes) budgetUpdates.notes = budgetItem.notes;

          if (Object.keys(budgetUpdates).length > 0) {
            const { error: budgetUpdateError } = await supabaseService
              .from('budget_tracker')
              .update(budgetUpdates)
              .eq('id', existingBudget.id);

            if (budgetUpdateError) {
              console.error('Failed to update budget:', budgetUpdateError);
            } else {
              console.log('Successfully updated budget category:', budgetItem.category);
            }
          }
        } else {
          // Insert new budget category
          const { error: budgetInsertError } = await supabaseService
            .from('budget_tracker')
            .insert({
              wedding_id: membership.wedding_id,
              category: budgetItem.category,
              budgeted_amount: budgetItem.budgeted_amount || 0,
              spent_amount: budgetItem.spent_amount || 0,
              last_transaction_date: budgetItem.transaction_date,
              last_transaction_amount: budgetItem.transaction_amount,
              last_transaction_description: budgetItem.transaction_description,
              notes: budgetItem.notes
            });

          if (budgetInsertError) {
            console.error('Failed to insert budget:', budgetInsertError);
          } else {
            console.log('Successfully inserted budget category:', budgetItem.category);
          }
        }
      }
    }

    // 2. Insert tasks in wedding_tasks table
    if (extractedData.tasks && extractedData.tasks.length > 0) {
      for (const task of extractedData.tasks) {
        const { error: taskInsertError } = await supabaseService
          .from('wedding_tasks')
          .insert({
            wedding_id: membership.wedding_id,
            ...task
          });

        if (taskInsertError) {
          console.error('Failed to insert task:', taskInsertError);
        } else {
          console.log('Successfully inserted task:', task.task_name);
        }
      }
    }

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
      conversationId: conversationId || 'bestie-temp',
      extractedData: extractedData // For debugging
    });

  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: error.message });
  }
}

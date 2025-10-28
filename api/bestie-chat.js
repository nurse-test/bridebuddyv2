import { createClient } from '@supabase/supabase-js';
import { handleCORS, rateLimitMiddleware, RATE_LIMITS } from './_utils/rate-limiter.js';

export default async function handler(req, res) {
  // Handle CORS preflight
  if (handleCORS(req, res)) {
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Apply rate limiting (30 requests per minute for chat)
  if (!rateLimitMiddleware(req, res, RATE_LIMITS.MODERATE)) {
    return;
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

    // Get user's wedding and role
    const { data: membership, error: memberError } = await supabase
      .from('wedding_members')
      .select('wedding_id, role')
      .eq('user_id', user.id)
      .single();

    if (memberError || !membership) throw new Error('No wedding profile found');

    // Only besties can access bestie chat
    if (membership.role !== 'bestie') {
      return res.status(403).json({
        error: 'Only besties can access bestie chat. Please use the main wedding chat instead.',
        redirect: '/dashboard-luxury.html'
      });
    }

    const { data: weddingData, error: weddingError } = await supabase
      .from('wedding_profiles')
      .select('*')
      .eq('id', membership.wedding_id)
      .single();

    if (weddingError || !weddingData) throw new Error('Wedding profile not found');

    // Ensure bestie_profile exists (UI expects this table to be populated)
    const { data: bestieProfile } = await supabaseService
      .from('bestie_profile')
      .select('id')
      .eq('bestie_user_id', user.id)
      .eq('wedding_id', membership.wedding_id)
      .maybeSingle();

    if (!bestieProfile) {
      // Create bestie_profile if it doesn't exist
      const { error: profileError } = await supabaseService
        .from('bestie_profile')
        .insert({
          bestie_user_id: user.id,
          wedding_id: membership.wedding_id,
          bestie_brief: 'Welcome! Chat with me to start planning your bestie duties and surprises.'
        });

      if (profileError) {
        console.error('Failed to create bestie profile:', profileError);
        // Don't fail the request - continue with chat
      }
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

YOUR CONVERSATIONAL APPROACH (CRITICAL):
1. **Guide toward concrete next steps**: After each discussion, suggest 2-3 specific tasks with deadlines
2. **Ask timeline questions**: "When are you thinking of doing this?" "What's the wedding date again?"
3. **Create urgency**: Calculate backwards from wedding date to suggest when things should happen
4. **Break down big ideas**: Turn vague ideas like "plan bachelorette party" into specific tasks:
   - "Book venue by [date]"
   - "Send invites by [date]"
   - "Collect RSVPs by [date]"
5. **Follow up on existing tasks**: Reference incomplete tasks from their profile and ask about progress

PERSONALITY:
- Friendly, practical, and organized
- Understanding of the unique pressures of being MOH/Best Man
- Budget-conscious and creative with party planning
- Supportive when dealing with difficult bridesmaids or family
- Use casual language but stay focused on actionable advice
- **PROACTIVE**: Always end responses by suggesting next concrete steps with dates

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

TASK: Help the Maid of Honor/Best Man with their wedding planning duties, event coordination, AND actively guide them toward creating concrete tasks with deadlines.

USER MESSAGE: "${message}"

INSTRUCTIONS:
1. Provide practical, actionable advice for MOH/Best Man responsibilities
2. Help plan bachelorette parties, bridal showers, and engagement parties
3. **PROACTIVELY suggest 2-3 specific next steps with dates** in your response
4. Extract planning details, budget info, and tasks (including the tasks you suggest!)
5. Return your response in this EXACT format:

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
  ],
  "profile_summary": "2-3 sentence summary of the bestie's current planning focus, events being organized, and key responsibilities. Update this each time to reflect the full conversation context."
}
</extracted_data>

EXTRACTION RULES FOR BESTIE CHAT:
- budget_items: Extract mentions of party expenses, bridesmaid costs, event budgets
  * "Spent $300 on bachelorette decorations" → {"category": "decorations", "spent_amount": 300, "transaction_amount": 300, "transaction_date": "today"}
  * "Budgeted $2000 for bridal shower venue" → {"category": "venue", "budgeted_amount": 2000}
  * "Bridesmaids dresses cost $150 each" → {"category": "attire", "transaction_amount": 150, "notes": "per bridesmaid"}
- tasks: **CRITICAL** - Extract ALL tasks including:
  * Tasks the user mentions
  * **Tasks YOU suggest in your response** (this is key!)
  * Example: If you say "You should book the venue by March 15th", extract: {"task_name": "Book bachelorette venue", "due_date": "2025-03-15", "status": "not_started", "priority": "high"}
- profile_summary: **ALWAYS provide** - Summarize the bestie's planning activities and responsibilities
  * Include: Events being planned (bachelorette, shower, etc.), current focus areas, key upcoming deadlines
  * Example: "Planning a beach bachelorette party for March with a $2000 budget. Coordinating bridesmaid dress shopping and organizing a bridal shower. Currently researching venues and creating a guest list."
  * Keep it concise but informative (2-3 sentences max)

TASK GENERATION EXAMPLES:
- User: "I'm thinking about a beach bachelorette"
  YOU SAY: "Love it! Here's what you should do: 1) Research beach house rentals by Feb 1st, 2) Get a headcount by Feb 15th, 3) Book the place by March 1st"
  YOU EXTRACT: [
    {"task_name": "Research beach house rentals", "due_date": "2025-02-01", "status": "not_started", "priority": "high"},
    {"task_name": "Get headcount for bachelorette", "due_date": "2025-02-15", "status": "not_started", "priority": "high"},
    {"task_name": "Book beach house", "due_date": "2025-03-01", "status": "not_started", "priority": "high"}
  ]

IMPORTANT:
- Today's date is ${new Date().toISOString().split('T')[0]}
- Wedding date is ${weddingData.wedding_date || 'unknown'} - calculate deadlines working backwards from this!
- Focus on extracting MOH/Best Man event planning data (bachelorette, shower, rehearsal dinner, etc.)
- Only include sections that have data. Empty arrays [] are ok if nothing was mentioned
- **ALWAYS generate tasks with specific due dates** when giving advice`
        }]
      })
    });

    // Check if API call was successful
    if (!claudeResponse.ok) {
      const errorData = await claudeResponse.json();
      console.error('Anthropic API error:', errorData);
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
    let extractedData = { budget_items: [], tasks: [], profile_summary: null };

    if (dataMatch) {
      try {
        const jsonStr = dataMatch[1].trim();
        extractedData = JSON.parse(jsonStr);
      } catch (e) {
        console.error('Failed to parse extracted data:', e);
      }
    }

    // Update database with extracted data from bestie chat

    // 1. Insert/Update budget items in budget_tracker table (BATCHED)
    if (extractedData.budget_items && extractedData.budget_items.length > 0) {
      // Fetch all existing budget items for this wedding in one query
      const { data: existingBudgets } = await supabaseService
        .from('budget_tracker')
        .select('id, category, spent_amount')
        .eq('wedding_id', membership.wedding_id);

      const existingBudgetMap = new Map();
      if (existingBudgets) {
        existingBudgets.forEach(b => {
          existingBudgetMap.set(b.category, { id: b.id, spent_amount: b.spent_amount });
        });
      }

      const budgetsToInsert = [];
      const budgetsToUpdate = [];

      for (const budgetItem of extractedData.budget_items) {
        const existing = existingBudgetMap.get(budgetItem.category);

        if (existing) {
          // Prepare for batch update
          const budgetUpdates = {};

          if (budgetItem.budgeted_amount !== null && budgetItem.budgeted_amount !== undefined) {
            budgetUpdates.budgeted_amount = budgetItem.budgeted_amount;
          }

          if (budgetItem.spent_amount !== null && budgetItem.spent_amount !== undefined) {
            budgetUpdates.spent_amount = (existing.spent_amount || 0) + budgetItem.spent_amount;
          }

          if (budgetItem.transaction_date) budgetUpdates.last_transaction_date = budgetItem.transaction_date;
          if (budgetItem.transaction_amount) budgetUpdates.last_transaction_amount = budgetItem.transaction_amount;
          if (budgetItem.transaction_description) budgetUpdates.last_transaction_description = budgetItem.transaction_description;
          if (budgetItem.notes) budgetUpdates.notes = budgetItem.notes;

          if (Object.keys(budgetUpdates).length > 0) {
            budgetsToUpdate.push({ id: existing.id, updates: budgetUpdates });
          }
        } else {
          // Prepare for batch insert
          budgetsToInsert.push({
            wedding_id: membership.wedding_id,
            category: budgetItem.category,
            budgeted_amount: budgetItem.budgeted_amount || 0,
            spent_amount: budgetItem.spent_amount || 0,
            last_transaction_date: budgetItem.transaction_date,
            last_transaction_amount: budgetItem.transaction_amount,
            last_transaction_description: budgetItem.transaction_description,
            notes: budgetItem.notes
          });
        }
      }

      // Batch insert new budget items
      if (budgetsToInsert.length > 0) {
        const { error: budgetInsertError } = await supabaseService
          .from('budget_tracker')
          .insert(budgetsToInsert);

        if (budgetInsertError) {
          console.error('Failed to batch insert budgets:', budgetInsertError);
        }
      }

      // Batch update existing budget items (in parallel)
      if (budgetsToUpdate.length > 0) {
        await Promise.all(
          budgetsToUpdate.map(({ id, updates }) =>
            supabaseService
              .from('budget_tracker')
              .update(updates)
              .eq('id', id)
              .then(({ error }) => {
                if (error) console.error('Failed to update budget:', error);
              })
          )
        );
      }
    }

    // 2. Insert tasks in wedding_tasks table (BATCHED)
    if (extractedData.tasks && extractedData.tasks.length > 0) {
      const tasksToInsert = extractedData.tasks.map(task => ({
        wedding_id: membership.wedding_id,
        ...task
      }));

      const { error: taskInsertError } = await supabaseService
        .from('wedding_tasks')
        .insert(tasksToInsert);

      if (taskInsertError) {
        console.error('Failed to batch insert tasks:', taskInsertError);
      }
    }

    // 3. Update bestie_profile with conversation summary
    if (extractedData.profile_summary && extractedData.profile_summary.trim()) {
      const { error: profileUpdateError } = await supabaseService
        .from('bestie_profile')
        .update({
          bestie_brief: extractedData.profile_summary,
          updated_at: new Date().toISOString()
        })
        .eq('bestie_user_id', user.id)
        .eq('wedding_id', membership.wedding_id);

      if (profileUpdateError) {
        console.error('Failed to update bestie profile:', profileUpdateError);
        // Don't fail the request if profile update fails
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
    // Security: Only log error message, not full error object (may contain user messages, bestie data, user/wedding IDs)
    console.error('Bestie chat error:', error.message || 'Unknown error');
    return res.status(500).json({ error: error.message || 'Chat processing failed' });
  }
}

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
    if (userError || !user) {
      throw new Error('Invalid user token');
    }

    // Get user's wedding and role
    const { data: membership, error: memberError } = await supabase
      .from('wedding_members')
      .select('wedding_id, role')
      .eq('user_id', user.id)
      .single();

    if (memberError || !membership) {
      throw new Error('No wedding profile found');
    }

    // Block bestie access to wedding chat - they should use bestie chat
    if (membership.role === 'bestie') {
      return res.status(403).json({
        error: 'Besties cannot access wedding chat. Please use the bestie planning chat instead.',
        redirect: '/bestie-luxury.html'
      });
    }

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

    // CALL CLAUDE with full extraction prompt (vendors, budget, tasks)
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

TASK: Extract wedding information from the user's message and respond proactively.

USER MESSAGE: "${message}"

INSTRUCTIONS:
1. Respond warmly and helpfully AND proactively guide them forward:
   - Acknowledge what they shared
   - Calculate urgency: Wedding is ${weddingData.wedding_date ? `${Math.ceil((new Date(weddingData.wedding_date) - new Date()) / (1000*60*60*24))} days away` : 'not set yet'}
   - Based on timeline, suggest the NEXT 1-2 concrete steps (not overwhelming list)
   - Ask ONE follow-up question to move planning forward (not multiple questions)
   - Timeline-based guidance:
     * <6 months: Emphasize urgency on vendor bookings and final details
     * 6-12 months: Focus on major decisions (venue, caterer, photographer, dress)
     * >12 months: Focus on foundation (setting budget, defining style, initial vendor research)
     * No wedding date set: Encourage setting one to enable timeline planning

2. Extract ALL wedding details from the message including:
   - General info (dates, location, guest count, style preferences)
   - Vendors (name, type, cost, deposit status)
   - Budget items (category, amount, paid/unpaid)
   - Tasks (what needs to be done, when)

3. Return your response in this EXACT format:

<response>Your natural, conversational response here</response>

<extracted_data>
{
  "wedding_info": {
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
    "wedding_style": "string or null"
  },
  "vendors": [
    {
      "vendor_type": "photographer|caterer|florist|dj|videographer|baker|planner|venue|decorator|hair_makeup|transportation|rentals|other",
      "vendor_name": "string",
      "vendor_contact_name": "string or null",
      "vendor_email": "string or null",
      "vendor_phone": "string or null",
      "total_cost": number or null,
      "deposit_amount": number or null,
      "deposit_paid": true|false|null,
      "deposit_date": "YYYY-MM-DD or null",
      "balance_due": number or null,
      "final_payment_date": "YYYY-MM-DD or null",
      "final_payment_paid": true|false|null,
      "status": "inquiry|pending|booked|contract_signed|deposit_paid|fully_paid|rejected|cancelled or null",
      "contract_signed": true|false|null,
      "contract_date": "YYYY-MM-DD or null",
      "service_date": "YYYY-MM-DD or null",
      "notes": "string or null"
    }
  ],
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

EXTRACTION RULES:
- wedding_info: Extract basic wedding details
- vendors: Extract ANY mention of vendors with detailed tracking. Examples:
  * "I paid the florist $500 deposit" → {"vendor_type": "florist", "deposit_amount": 500, "deposit_paid": true, "deposit_date": "today's date"}
  * "We booked Sarah's Photography for $3000" → {"vendor_type": "photographer", "vendor_name": "Sarah's Photography", "total_cost": 3000, "status": "booked"}
  * "Called the caterer, deposit due next week" → {"vendor_type": "caterer", "status": "pending", "deposit_paid": false}
- budget_items: Extract payments, spending, or budget allocations
  * "Paid $500 for flowers" → {"category": "flowers", "spent_amount": 500, "transaction_amount": 500, "transaction_date": "today's date"}
  * "Budgeted $5000 for catering" → {"category": "catering", "budgeted_amount": 5000}
- tasks: Extract any to-dos, deadlines, or action items
  * "Need to mail invitations by March 15" → {"task_name": "Mail invitations", "category": "invitations", "due_date": "2025-03-15", "status": "not_started"}
  * "Finished picking flowers!" → {"task_name": "Pick flowers", "category": "flowers", "status": "completed"}

IMPORTANT:
- Today's date is ${new Date().toISOString().split('T')[0]}
- Only include sections that have data. Empty arrays [] are ok if nothing was mentioned
- If nothing wedding-related was mentioned, return {"wedding_info": {}, "vendors": [], "budget_items": [], "tasks": []}`
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
    let extractedData = { wedding_info: {}, vendors: [], budget_items: [], tasks: [] };

    if (dataMatch) {
      try {
        const jsonStr = dataMatch[1].trim();
        extractedData = JSON.parse(jsonStr);
      } catch (e) {
        console.error('Failed to parse extracted data:', e);
      }
    }

    // Update database with extracted data (FULL extraction restored)

    // 1. Update wedding_profiles with general wedding info
    if (extractedData.wedding_info && Object.keys(extractedData.wedding_info).length > 0) {
      const weddingUpdates = {};

      Object.keys(extractedData.wedding_info).forEach(key => {
        if (extractedData.wedding_info[key] !== null && extractedData.wedding_info[key] !== undefined) {
          weddingUpdates[key] = extractedData.wedding_info[key];
        }
      });

      if (Object.keys(weddingUpdates).length > 0) {
        const { error: updateError } = await supabaseService
          .from('wedding_profiles')
          .update(weddingUpdates)
          .eq('id', membership.wedding_id);

        if (updateError) {
          console.error('Failed to update wedding profile:', updateError);
        }
      }
    }

    // 2. Insert/Update vendors in vendor_tracker table
    if (extractedData.vendors && extractedData.vendors.length > 0) {
      for (const vendor of extractedData.vendors) {
        // Check if vendor already exists
        const { data: existingVendor } = await supabaseService
          .from('vendor_tracker')
          .select('id')
          .eq('wedding_id', membership.wedding_id)
          .eq('vendor_type', vendor.vendor_type)
          .ilike('vendor_name', vendor.vendor_name || '%')
          .single();

        if (existingVendor) {
          // Update existing vendor
          const vendorUpdates = { ...vendor };
          delete vendorUpdates.vendor_type; // Don't change type
          delete vendorUpdates.vendor_name; // Don't change name

          const { error: vendorUpdateError } = await supabaseService
            .from('vendor_tracker')
            .update(vendorUpdates)
            .eq('id', existingVendor.id);

          if (vendorUpdateError) {
            console.error('Failed to update vendor:', vendorUpdateError);
          }
        } else {
          // Insert new vendor
          const { error: vendorInsertError } = await supabaseService
            .from('vendor_tracker')
            .insert({
              wedding_id: membership.wedding_id,
              ...vendor
            });

          if (vendorInsertError) {
            console.error('Failed to insert vendor:', vendorInsertError);
          }
        }
      }
    }

    // 3. Insert/Update budget items in budget_tracker table
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
          }
        }
      }
    }

    // 4. Insert tasks in wedding_tasks table
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
        }
      }
    }

    assistantMessage += trialWarning;

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
          message_type: 'main'
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
          message_type: 'main'
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
      conversationId: conversationId || 'temp',
      daysLeftInTrial: daysLeft,
      extractedData: extractedData // For debugging
    });

  } catch (error) {
    // Security: Only log error message, not full error object (may contain user messages, wedding data, user/wedding IDs)
    console.error('Chat error:', error.message || 'Unknown error');
    return res.status(500).json({ error: error.message || 'Chat processing failed' });
  }
}

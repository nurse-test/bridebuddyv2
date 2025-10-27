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

    // Get user's wedding and verify they're a bestie
    const { data: membership, error: memberError } = await supabase
      .from('wedding_members')
      .select('wedding_id, role')
      .eq('user_id', user.id)
      .single();

    if (memberError || !membership) throw new Error('No wedding profile found');

    // Verify user is a bestie
    if (membership.role !== 'bestie') {
      return res.status(403).json({
        error: 'Only besties can access bestie chat'
      });
    }

    const { data: weddingData, error: weddingError } = await supabase
      .from('wedding_profiles')
      .select('*')
      .eq('id', membership.wedding_id)
      .single();

    if (weddingError || !weddingData) throw new Error('Wedding profile not found');

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

    // Get existing bestie profile
    const { data: bestieProfile } = await supabaseService
      .from('bestie_profile')
      .select('*')
      .eq('bestie_user_id', user.id)
      .eq('wedding_id', membership.wedding_id)
      .single();

    if (bestieProfile) {
      weddingContext += `\n\nYOUR CURRENT BESTIE PROFILE:`;
      if (bestieProfile.bestie_brief) weddingContext += `\n- Brief: ${bestieProfile.bestie_brief}`;
      if (bestieProfile.event_details) weddingContext += `\n- Event Details: ${JSON.stringify(bestieProfile.event_details)}`;
      if (bestieProfile.budget_info) weddingContext += `\n- Budget: ${JSON.stringify(bestieProfile.budget_info)}`;
      if (bestieProfile.tasks) weddingContext += `\n- Tasks: ${JSON.stringify(bestieProfile.tasks)}`;
    }

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
  "bestie_profile": {
    "bestie_brief": "High-level summary of bestie responsibilities and current status (1-2 sentences)",
    "event_details": {
      "bachelorette_party": {
        "date": "YYYY-MM-DD or null",
        "location": "string or null",
        "theme": "string or null",
        "guest_count": number or null,
        "notes": "string or null"
      },
      "bridal_shower": {
        "date": "YYYY-MM-DD or null",
        "location": "string or null",
        "theme": "string or null",
        "guest_count": number or null,
        "notes": "string or null"
      },
      "rehearsal_dinner": {
        "date": "YYYY-MM-DD or null",
        "location": "string or null",
        "notes": "string or null"
      }
    },
    "guest_info": {
      "bridesmaids": [],
      "groomsmen": [],
      "invitees": []
    },
    "budget_info": {
      "bachelorette_budget": number or null,
      "bridal_shower_budget": number or null,
      "spent_so_far": number or null,
      "breakdown": {}
    },
    "tasks": [
      {
        "task": "string",
        "due_date": "YYYY-MM-DD or null",
        "completed": true|false,
        "priority": "low|medium|high",
        "notes": "string or null"
      }
    ]
  }
}
</extracted_data>

EXTRACTION RULES FOR BESTIE CHAT:
- bestie_brief: One-line summary of what you're currently working on
- event_details: Extract details about bachelorette/bachelor party, bridal shower, rehearsal dinner
  * "Planning a beach bachelorette on July 10th for 12 girls" → bachelorette_party: {date, location, guest_count}
  * "Bridal shower theme is tea party at my house" → bridal_shower: {theme, location}
- guest_info: Names of bridesmaids, groomsmen, who's invited to events
- budget_info: Budget allocations and spending for bestie-hosted events
  * "Budgeted $2000 for bachelorette" → bachelorette_budget: 2000
  * "Spent $300 on decorations" → spent_so_far: 300, breakdown: {decorations: 300}
- tasks: To-dos for bestie duties
  * "Need to book venue by Friday" → {task, due_date, completed: false}

IMPORTANT:
- Today's date is ${new Date().toISOString().split('T')[0]}
- Only update fields that are mentioned in the message
- Merge with existing profile data, don't overwrite everything
- Return null for fields not mentioned`
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
    let extractedData = { bestie_profile: null };

    if (dataMatch) {
      try {
        const jsonStr = dataMatch[1].trim();
        extractedData = JSON.parse(jsonStr);
      } catch (e) {
        console.error('Failed to parse extracted data:', e);
      }
    }

    // Update bestie_profile with extracted data
    console.log('Bestie extracted data:', JSON.stringify(extractedData, null, 2));

    if (extractedData.bestie_profile) {
      const profileData = extractedData.bestie_profile;

      // Build the update object (merge with existing data)
      const profileUpdate = {};

      if (profileData.bestie_brief) {
        profileUpdate.bestie_brief = profileData.bestie_brief;
      }

      if (profileData.event_details) {
        // Merge event details with existing
        const existingEventDetails = bestieProfile?.event_details || {};
        profileUpdate.event_details = {
          ...existingEventDetails,
          ...profileData.event_details
        };
      }

      if (profileData.guest_info) {
        // Merge guest info
        const existingGuestInfo = bestieProfile?.guest_info || {};
        profileUpdate.guest_info = {
          ...existingGuestInfo,
          ...profileData.guest_info
        };
      }

      if (profileData.budget_info) {
        // Merge budget info
        const existingBudgetInfo = bestieProfile?.budget_info || {};
        profileUpdate.budget_info = {
          ...existingBudgetInfo,
          ...profileData.budget_info
        };
      }

      if (profileData.tasks) {
        // Append new tasks to existing tasks
        const existingTasks = bestieProfile?.tasks || [];
        profileUpdate.tasks = [...existingTasks, ...profileData.tasks];
      }

      if (Object.keys(profileUpdate).length > 0) {
        const { error: profileUpdateError } = await supabaseService
          .from('bestie_profile')
          .update(profileUpdate)
          .eq('bestie_user_id', user.id)
          .eq('wedding_id', membership.wedding_id);

        if (profileUpdateError) {
          console.error('Failed to update bestie profile:', profileUpdateError);
        } else {
          console.log('Successfully updated bestie profile');
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

// ============================================================================
// CREATE WEDDING - VERCEL FUNCTION (SECURE)
// ============================================================================
// Creates a new wedding profile for authenticated user
// SECURITY: Properly verifies user authentication before creating wedding
// ============================================================================

import { createClient } from '@supabase/supabase-js';

// Service role client (bypasses RLS for admin operations)
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const {
    userToken,  // ✅ CHANGED: Now requires userToken instead of userId
    coupleNames,
    weddingDate,
    partner1Name,
    partner2Name,
    weddingTime,
    ceremonyLocation,
    receptionLocation,
    expectedGuestCount,
    totalBudget,
    weddingStyle,
    colorSchemePrimary
  } = req.body;

  // ========================================================================
  // STEP 1: Validate required authentication token
  // ========================================================================
  if (!userToken) {
    return res.status(400).json({
      error: 'Missing required field: userToken'
    });
  }

  try {
    // ========================================================================
    // STEP 2: Authenticate the user (SECURITY FIX)
    // ========================================================================
    const supabaseUser = createClient(
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

    // Verify user authentication
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return res.status(401).json({
        error: 'Unauthorized - invalid or expired token'
      });
    }

    // ✅ SECURITY FIX: Now using verified user ID from authenticated session
    const userId = user.id;

    // ========================================================================
    // STEP 3: Check if user already has a wedding
    // ========================================================================
    const { data: existingMembership } = await supabaseAdmin
      .from('wedding_members')
      .select('wedding_id')
      .eq('user_id', userId)
      .eq('role', 'owner')
      .single();

    if (existingMembership) {
      return res.status(400).json({
        error: 'User already has a wedding'
      });
    }

    // ========================================================================
    // STEP 4: Build wedding profile data
    // ========================================================================
    const weddingData = {
      owner_id: userId,

      // Subscription & Trial Fields
      trial_start_date: new Date().toISOString(),
      trial_end_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(), // 7 day trial
      plan_type: 'trial',
      subscription_status: 'trialing',
      bestie_addon_enabled: true, // Enable bestie for all new weddings
      is_vip: false
    };

    // Add optional fields
    if (coupleNames) weddingData.wedding_name = coupleNames;
    if (weddingDate) weddingData.wedding_date = weddingDate;
    if (partner1Name) weddingData.partner1_name = partner1Name;
    if (partner2Name) weddingData.partner2_name = partner2Name;
    if (weddingTime) weddingData.wedding_time = weddingTime;
    if (ceremonyLocation) weddingData.ceremony_location = ceremonyLocation;
    if (receptionLocation) weddingData.reception_location = receptionLocation;
    if (expectedGuestCount) weddingData.expected_guest_count = parseInt(expectedGuestCount);
    if (totalBudget) weddingData.total_budget = parseFloat(totalBudget);
    if (weddingStyle) weddingData.wedding_style = weddingStyle;
    if (colorSchemePrimary) weddingData.color_scheme_primary = colorSchemePrimary;

    // ========================================================================
    // STEP 5: Create wedding profile
    // ========================================================================
    const { data: wedding, error: weddingError } = await supabaseAdmin
      .from('wedding_profiles')
      .insert(weddingData)
      .select()
      .single();

    if (weddingError) {
      console.error('Wedding creation error:', weddingError);
      return res.status(500).json({
        error: 'Failed to create wedding profile',
        details: weddingError.message
      });
    }

    // ========================================================================
    // STEP 6: Add owner to wedding_members
    // ========================================================================
    const { error: memberError } = await supabaseAdmin
      .from('wedding_members')
      .insert({
        wedding_id: wedding.id,
        user_id: userId,  // ✅ Verified user ID
        role: 'owner'
      });

    if (memberError) {
      console.error('Member creation error:', memberError);

      // Rollback: Delete the wedding profile if member creation fails
      await supabaseAdmin
        .from('wedding_profiles')
        .delete()
        .eq('id', wedding.id);

      return res.status(500).json({
        error: 'Failed to set up wedding membership',
        details: memberError.message
      });
    }

    // ========================================================================
    // STEP 7: Return success response
    // ========================================================================
    return res.status(200).json({
      success: true,
      wedding_id: wedding.id,  // Changed to snake_case for consistency
      message: 'Wedding created successfully'
    });

  } catch (error) {
    console.error('Unexpected error creating wedding:', error);
    return res.status(500).json({
      error: 'Internal server error',
      details: error.message
    });
  }
}

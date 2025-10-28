import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // SECURITY: Accept userToken and weddingId, verify server-side
  const { priceId, userToken, weddingId } = req.body;

  if (!priceId || !userToken || !weddingId) {
    return res.status(400).json({ error: 'Missing required fields: priceId, userToken, weddingId' });
  }

  try {
    // ========================================================================
    // STEP 1: Authenticate user (don't trust client-supplied userId)
    // ========================================================================
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

    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return res.status(401).json({
        error: 'Unauthorized - invalid or expired token'
      });
    }

    // ========================================================================
    // STEP 2: Verify user owns or has access to this wedding
    // ========================================================================
    const supabaseAdmin = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    const { data: membership, error: memberError } = await supabaseAdmin
      .from('wedding_members')
      .select('role')
      .eq('user_id', user.id)
      .eq('wedding_id', weddingId)
      .single();

    if (memberError || !membership) {
      return res.status(403).json({
        error: 'Forbidden - you do not have access to this wedding'
      });
    }

    // Only owner can purchase plans
    if (membership.role !== 'owner') {
      return res.status(403).json({
        error: 'Forbidden - only wedding owner can purchase plans'
      });
    }

    // ========================================================================
    // STEP 3: Get verified wedding data
    // ========================================================================
    const { data: wedding, error: weddingError } = await supabaseAdmin
      .from('wedding_profiles')
      .select('owner_id, wedding_name')
      .eq('id', weddingId)
      .single();

    if (weddingError || !wedding) {
      return res.status(404).json({
        error: 'Wedding not found'
      });
    }

    // Double-check ownership
    if (wedding.owner_id !== user.id) {
      return res.status(403).json({
        error: 'Forbidden - you are not the owner of this wedding'
      });
    }

    // ========================================================================
    // STEP 4: Create Stripe checkout session with VERIFIED data
    // ========================================================================
    const session = await stripe.checkout.sessions.create({
      mode: priceId === 'price_1SHYkGDn8y3nIH6VnJNyAsE1' ? 'subscription' : 'payment',
      payment_method_types: ['card'],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      // Use environment variables for URLs (not hard-coded production URLs)
      success_url: `${process.env.APP_URL || 'https://bridebuddyv2.vercel.app'}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.APP_URL || 'https://bridebuddyv2.vercel.app'}/paywall.html`,
      metadata: {
        // SECURITY: Use VERIFIED user.id and weddingId (not client-supplied)
        userId: user.id,
        weddingId: weddingId,
        userEmail: user.email,
        weddingName: wedding.wedding_name || 'Unnamed Wedding',
        planType: priceId === 'price_1SHYkGDn8y3nIH6VnJNyAsE1' ? 'monthly' : (priceId === 'price_1SHYjrDn8y3nIH6VtE3aORiS' ? 'until_i_do' : 'unknown')
      }
    });

    return res.status(200).json({ sessionId: session.id, url: session.url });
  } catch (error) {
    console.error('Stripe checkout error:', error);
    return res.status(500).json({ error: error.message });
  }
}

import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';
import { CORS_HEADERS } from './_utils/rate-limiter.js';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export const config = {
  api: {
    bodyParser: false,
  },
};

async function buffer(readable) {
  const chunks = [];
  for await (const chunk of readable) {
    chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
  }
  return Buffer.concat(chunks);
}

export default async function handler(req, res) {
  // Set CORS headers (webhook endpoints typically don't need full CORS handling)
  Object.entries(CORS_HEADERS).forEach(([key, value]) => {
    res.setHeader(key, value);
  });

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const buf = await buffer(req);
  const sig = req.headers['stripe-signature'];

  let event;

  try {
    event = stripe.webhooks.constructEvent(
      buf,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).json({ error: `Webhook Error: ${err.message}` });
  }

  // Handle checkout.session.completed
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    const { userId, weddingId, planType } = session.metadata;

    console.log('Payment succeeded for wedding:', weddingId);

    try {
      // Update wedding to VIP
      const updates = {
        is_vip: true,
        plan_type: planType,
        subscription_start_date: new Date().toISOString(),
        stripe_customer_id: session.customer,
        stripe_subscription_id: session.subscription || null
      };

      // Enable bestie addon if plan includes "bestie"
      if (planType && planType.includes('bestie')) {
        updates.bestie_addon_enabled = true;
        console.log('Enabling bestie addon for plan:', planType);
      }

      // If "Until I Do" plan, set expiration to wedding date
      if (planType && (planType.includes('until_i_do') || planType === 'until_i_do')) {
        const { data: wedding } = await supabase
          .from('wedding_profiles')
          .select('wedding_date')
          .eq('id', weddingId)
          .single();

        if (wedding && wedding.wedding_date) {
          updates.subscription_end_date = wedding.wedding_date;
        }
      }

      const { error } = await supabase
        .from('wedding_profiles')
        .update(updates)
        .eq('id', weddingId);

      if (error) {
        console.error('Failed to update wedding:', error);
        return res.status(500).json({ error: 'Database update failed' });
      }

      console.log('Successfully activated VIP for wedding:', weddingId);
    } catch (err) {
      console.error('Error processing payment:', err);
      return res.status(500).json({ error: 'Payment processing failed' });
    }
  }

  // Handle subscription cancellation
  if (event.type === 'customer.subscription.deleted') {
    const subscription = event.data.object;
    
    try {
      const { error } = await supabase
        .from('wedding_profiles')
        .update({ 
          is_vip: false,
          subscription_end_date: new Date().toISOString()
        })
        .eq('stripe_subscription_id', subscription.id);

      if (error) {
        console.error('Failed to cancel subscription:', error);
      }
    } catch (err) {
      console.error('Error canceling subscription:', err);
    }
  }

  res.status(200).json({ received: true });
}

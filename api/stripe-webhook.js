import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';

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

  // Handle the event
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    const { userId, weddingId, planType } = session.metadata;

    console.log('Payment succeeded for user:', userId);

    // Update wedding to VIP
    const updates = {
      is_vip: true,
    };

    // If "Until I Do" plan, set expiration to wedding date
    if (planType === 'until_i_do') {
      const { data: wedding } = await supabase
        .from('wedding_profiles')
        .select('wedding_date')
        .eq('id', weddingId)
        .single();

      if (wedding && wedding.wedding_date) {
        updates.vip_expires_at = wedding.wedding_date;
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
  }

  res.status(200).json({ received: true });
}

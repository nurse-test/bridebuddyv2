import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { priceId, userId, weddingId } = req.body;

  if (!priceId || !userId || !weddingId) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const session = await stripe.checkout.sessions.create({
      mode: priceId === 'price_1SI3KoRjwBUM0ZBtUskqXPiY' ? 'subscription' : 'payment',
      payment_method_types: ['card'],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: `https://${process.env.VERCEL_URL || 'bridebuddyv2.vercel.app'}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `https://${process.env.VERCEL_URL || 'bridebuddyv2.vercel.app'}/paywall.html`,
      metadata: {
        userId,
        weddingId,
        planType: priceId === 'price_1SI3KoRjwBUM0ZBtUskqXPiY' ? 'monthly' : 'until_i_do'
      }
    });

    return res.status(200).json({ sessionId: session.id, url: session.url });
  } catch (error) {
    console.error('Stripe error:', error);
    return res.status(500).json({ error: error.message });
  }
}

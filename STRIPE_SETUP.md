# Stripe Configuration Guide

This document explains how to set up Stripe payment integration for Bride Buddy.

## Current Status

### ✅ Configured Price IDs
- **VIP Monthly**: `price_1SHYkGDn8y3nIH6VnJNyAsE1` ($12.99/month subscription)
- **VIP One-Time**: `price_1SHYjrDn8y3nIH6VtE3aORiS` ($99 one-time payment)

### ⚠️ Needs Configuration
- **VIP+Bestie Monthly**: `price_YOUR_BESTIE_MONTHLY` ($19.99/month subscription)
- **VIP+Bestie One-Time**: `price_YOUR_BESTIE_ONETIME` ($149 one-time payment)

## How to Create Stripe Price IDs

### Step 1: Access Stripe Dashboard
1. Log in to your Stripe account at https://dashboard.stripe.com
2. Navigate to **Products** in the left sidebar
3. Click **+ Add product**

### Step 2: Create VIP+Bestie Monthly Subscription
1. **Product name**: Bride Buddy VIP + Bestie (Monthly)
2. **Description**: All wedding planning features plus private bestie planning space
3. **Pricing model**: Standard pricing
4. **Price**: $19.99
5. **Billing period**: Monthly (recurring)
6. **Currency**: USD
7. Click **Save product**
8. **Copy the Price ID** (starts with `price_...`) from the product page

### Step 3: Create VIP+Bestie One-Time Payment
1. **Product name**: Bride Buddy VIP + Bestie (Until I Do)
2. **Description**: All wedding planning features plus bestie planning - valid until wedding day
3. **Pricing model**: Standard pricing
4. **Price**: $149
5. **Billing period**: One time
6. **Currency**: USD
7. Click **Save product**
8. **Copy the Price ID** (starts with `price_...`) from the product page

### Step 4: Update the Code
1. Open `/public/subscribe-luxury.html`
2. Find the `PRICE_IDS` object (around line 194)
3. Replace the placeholder values:
   ```javascript
   const PRICE_IDS = {
       'vip_monthly': 'price_1SHYkGDn8y3nIH6VnJNyAsE1',
       'vip_one_time': 'price_1SHYjrDn8y3nIH6VtE3aORiS',
       'vip_bestie_monthly': 'price_PASTE_YOUR_MONTHLY_ID_HERE',  // ← Update this
       'vip_bestie_one_time': 'price_PASTE_YOUR_ONETIME_ID_HERE'  // ← Update this
   };
   ```

### Step 5: Update Webhook Handler (if needed)
The webhook handler in `/api/stripe-webhook.js` automatically handles:
- VIP plan activation
- Bestie addon activation (when plan type includes "bestie")
- Subscription management
- Payment confirmation

No changes needed to the webhook handler - it will automatically recognize VIP+Bestie plans.

## Testing

### Test Mode
1. Use Stripe's test mode for development
2. Test credit card: `4242 4242 4242 4242`
3. Any future expiration date
4. Any 3-digit CVC

### Production
1. Switch to live mode in Stripe Dashboard
2. Update environment variables with live keys
3. Create live price IDs following the same steps
4. Test with a real payment

## Environment Variables

Ensure these are set in your deployment environment:
```
STRIPE_SECRET_KEY=sk_live_... (or sk_test_... for testing)
STRIPE_WEBHOOK_SECRET=whsec_...
```

## Trial Behavior

### Monthly Plans (Start Free Trial)
- **VIP Monthly**: Immediately starts 7-day trial, no payment required
- **VIP+Bestie Monthly**: Immediately starts 7-day trial with bestie addon enabled

### One-Time Plans
- **VIP One-Time**: Redirects to Stripe checkout, enables VIP until wedding day
- **VIP+Bestie One-Time**: Redirects to Stripe checkout, enables VIP+Bestie until wedding day

## Troubleshooting

### "This payment option is not yet configured"
- The price IDs in `subscribe-luxury.html` are still set to placeholders
- Follow Step 4 above to update them

### Webhook not firing
1. Check webhook URL in Stripe Dashboard: `https://yourdomain.com/api/stripe-webhook`
2. Verify webhook secret matches `STRIPE_WEBHOOK_SECRET` env variable
3. Check webhook logs in Stripe Dashboard

### Payment succeeded but features not enabled
1. Check webhook logs in Stripe Dashboard
2. Verify webhook is listening for `checkout.session.completed` event
3. Check server logs for errors in `/api/stripe-webhook.js`

## Security Notes

- ✅ Server-side verification: All checkout sessions are verified server-side using user tokens
- ✅ Webhook signature verification: All webhooks are verified using Stripe signatures
- ✅ Rate limiting: Checkout endpoint is rate-limited to prevent abuse
- ✅ Owner verification: Only wedding owners can purchase plans

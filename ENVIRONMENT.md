# Environment Variables Guide

This document describes all environment variables required to run Bride Buddy in development and production.

## Overview

Bride Buddy uses environment variables for configuration of:
- **Supabase** - Database, authentication, and storage
- **Stripe** - Payment processing and subscriptions
- **Anthropic** - AI chat functionality via Claude API

Environment variables are stored in `.env` files which are **gitignored** for security. Never commit `.env` files to version control.

## Quick Start

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Fill in all required values (see sections below)

3. For local development, the `.env` file will be automatically loaded by Vercel CLI

4. For production deployment, set environment variables in your Vercel project settings

## Required Environment Variables

### Supabase Configuration

Supabase provides the backend database, authentication, and real-time subscriptions.

#### `SUPABASE_URL`
- **Required**: Yes
- **Description**: Your Supabase project URL
- **Example**: `https://nluvnjydydotsrpluhey.supabase.co`
- **How to get**:
  1. Go to your [Supabase Dashboard](https://app.supabase.com)
  2. Select your project
  3. Go to Settings > API
  4. Copy the "Project URL"

#### `SUPABASE_ANON_KEY`
- **Required**: Yes (for backend API functions)
- **Description**: Public anonymous key for client-side Supabase access
- **Example**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
- **Security**: This key is safe to expose in client-side code as it respects Row Level Security (RLS) policies
- **How to get**:
  1. Go to your Supabase Dashboard
  2. Select your project
  3. Go to Settings > API
  4. Copy the "anon public" key under "Project API keys"

#### `SUPABASE_SERVICE_ROLE_KEY`
- **Required**: Yes
- **Description**: Secret service role key with full database access (bypasses RLS)
- **Example**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
- **Security**: ⚠️ **CRITICAL** - Never expose this key in client-side code. Only use in backend API functions.
- **Use cases**:
  - Admin operations that need to bypass RLS
  - Webhook handlers
  - Background jobs
- **How to get**:
  1. Go to your Supabase Dashboard
  2. Select your project
  3. Go to Settings > API
  4. Copy the "service_role" key under "Project API keys"

### Anthropic API Configuration

Anthropic Claude powers the AI wedding planning assistant.

#### `ANTHROPIC_API_KEY`
- **Required**: Yes
- **Description**: API key for Anthropic Claude AI
- **Example**: `sk-ant-api03-...`
- **Security**: ⚠️ Keep secret - only use in backend API functions
- **How to get**:
  1. Go to [Anthropic Console](https://console.anthropic.com/)
  2. Sign up or log in
  3. Go to API Keys
  4. Create a new API key
- **Pricing**: Pay-as-you-go based on usage. See [Anthropic Pricing](https://www.anthropic.com/pricing)

### Stripe Configuration

Stripe handles subscription billing and payment processing.

#### `STRIPE_SECRET_KEY`
- **Required**: Yes
- **Description**: Stripe secret key for backend API calls
- **Example**: `sk_test_...` (test) or `sk_live_...` (production)
- **Security**: ⚠️ **CRITICAL** - Never expose this key in client-side code
- **How to get**:
  1. Go to [Stripe Dashboard](https://dashboard.stripe.com/)
  2. Go to Developers > API keys
  3. Copy the "Secret key"
  4. Use test key for development, live key for production

#### `STRIPE_WEBHOOK_SECRET`
- **Required**: Yes (for webhook handlers)
- **Description**: Secret for verifying Stripe webhook signatures
- **Example**: `whsec_...`
- **Security**: Keep secret - used to verify webhook authenticity
- **How to get**:
  1. Go to Stripe Dashboard > Developers > Webhooks
  2. Add a webhook endpoint pointing to `https://yourdomain.com/api/stripe-webhook`
  3. Select events to listen for:
     - `checkout.session.completed`
     - `customer.subscription.created`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
  4. Copy the "Signing secret" after creating the webhook

#### Stripe Price IDs

You'll also need to configure Stripe Price IDs for your subscription plans. These are referenced in the code but can be updated in your Stripe Dashboard.

**Current Price IDs** (from `.env.example`):
- Monthly VIP: `price_1SHYkGDn8y3nIH6VnJNyAsE1`
- Until I Do (one-time): `price_1SHYjrDn8y3nIH6VtE3aORiS`

To create your own prices:
1. Go to Stripe Dashboard > Products
2. Create products for your subscription tiers
3. Add prices to each product
4. Copy the price IDs (start with `price_`)
5. Update your code references to these IDs

## Client-Side Configuration

### Security Best Practice

The Supabase anon key was previously hard-coded in `/public/js/shared.js`. This has been moved to a configuration system that:

1. **Development**: Uses a generated `config.js` file (gitignored)
2. **Production**: Uses environment variables injected at build time

### Setting Up Client-Side Config

#### For Local Development

Run the setup script to generate `config.js` from your `.env` file:

```bash
npm run build:config
```

This creates `/public/js/config.js` with your Supabase credentials. This file is gitignored.

#### For Production (Vercel)

The build process automatically injects environment variables during deployment. No manual steps needed.

## Environment Files

### `.env` (Development)
- Local development environment variables
- **Gitignored** - never commit this file
- Copy from `.env.example` and fill in real values

### `.env.example` (Template)
- Template showing all required variables
- Safe to commit - contains no real secrets
- Use placeholder values

### `.env.production` (Optional)
- Production-specific overrides
- Not needed if using Vercel environment variables

## Vercel Deployment

When deploying to Vercel:

1. Go to your project settings on Vercel
2. Navigate to "Environment Variables"
3. Add each variable listed above
4. Set the environment scope (Production, Preview, Development)
5. Redeploy your application

Variables set in Vercel will be available as `process.env.*` in your API functions.

## Security Checklist

- [ ] `.env` file is listed in `.gitignore`
- [ ] No hard-coded secrets in any committed code
- [ ] `SUPABASE_SERVICE_ROLE_KEY` only used in backend API functions
- [ ] `ANTHROPIC_API_KEY` only used in backend API functions
- [ ] `STRIPE_SECRET_KEY` only used in backend API functions
- [ ] Row Level Security (RLS) policies enabled on all Supabase tables
- [ ] Stripe webhook endpoints use signature verification
- [ ] Environment variables set in Vercel for production

## Troubleshooting

### "Supabase client not initialized"
- Ensure `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set
- Run `npm run build:config` to generate config.js
- Check that config.js is loaded before shared.js in HTML

### "Invalid API key" errors
- Verify you're using the correct key for your environment (test vs production)
- Check for extra spaces or newlines when copying keys
- Ensure keys haven't been regenerated in the service dashboard

### Stripe webhooks failing
- Verify `STRIPE_WEBHOOK_SECRET` matches your webhook endpoint
- Check webhook endpoint URL is correct in Stripe Dashboard
- Ensure webhook handler is deployed and accessible

### Chat not working
- Verify `ANTHROPIC_API_KEY` is valid and has credits
- Check API function logs for specific error messages
- Ensure rate limiting isn't blocking requests

## Related Documentation

- [Supabase Documentation](https://supabase.com/docs)
- [Stripe API Documentation](https://stripe.com/docs/api)
- [Anthropic API Documentation](https://docs.anthropic.com/)
- [Vercel Environment Variables](https://vercel.com/docs/concepts/projects/environment-variables)

## Support

If you encounter issues with environment configuration:

1. Check the [GitHub Issues](https://github.com/nurse-test/bridebuddyv2/issues)
2. Review Supabase/Stripe/Anthropic dashboard logs
3. Check Vercel deployment logs for errors

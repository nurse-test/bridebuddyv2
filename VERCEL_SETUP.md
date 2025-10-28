# Vercel Deployment Setup Guide

This guide covers how to properly configure environment variables for Vercel deployments to ensure the application works correctly in production.

## Overview

Bride Buddy uses a **static HTML frontend** with **Vercel serverless functions** for the backend API. The frontend needs access to public Supabase credentials, which are:

1. **Local Development**: Stored in `.env` file → generated into `public/js/config.js`
2. **Vercel Production**: Stored in Vercel dashboard → generated during build into `public/js/config.js`

## Critical Files

- `.env` - Local environment variables (gitignored)
- `.env.example` - Template showing required variables
- `public/js/config.js` - Auto-generated from environment variables (gitignored)
- `scripts/build-config.js` - Generates config.js from environment variables
- `package.json` - Contains `"build": "npm run build:config"` script

## Vercel Environment Variables Setup

### Step 1: Access Vercel Dashboard

1. Go to [vercel.com](https://vercel.com)
2. Navigate to your project: **bridebuddyv2**
3. Click **Settings** → **Environment Variables**

### Step 2: Add Required Environment Variables

Add the following environment variables. **All variables should be available in all environments** (Production, Preview, Development):

#### Supabase Configuration

| Variable Name | Value | Where to Get It | Environments |
|---------------|-------|-----------------|--------------|
| `SUPABASE_URL` | `https://nluvnjydydotsrpluhey.supabase.co` | [Supabase Dashboard](https://app.supabase.com) → Your Project → Settings → API | ✅ Production<br>✅ Preview<br>✅ Development |
| `SUPABASE_ANON_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` | [Supabase Dashboard](https://app.supabase.com) → Your Project → Settings → API → `anon` `public` | ✅ Production<br>✅ Preview<br>✅ Development |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` | [Supabase Dashboard](https://app.supabase.com) → Your Project → Settings → API → `service_role` `secret` | ✅ Production<br>✅ Preview<br>✅ Development |

**Important Notes:**
- `SUPABASE_ANON_KEY` is **safe for client-side** use (respects RLS policies)
- `SUPABASE_SERVICE_ROLE_KEY` is **backend-only** (bypasses RLS - keep secret!)

#### Anthropic API Configuration

| Variable Name | Value | Where to Get It | Environments |
|---------------|-------|-----------------|--------------|
| `ANTHROPIC_API_KEY` | `sk-ant-api03-...` | [Anthropic Console](https://console.anthropic.com/) → Account Settings → API Keys | ✅ Production<br>✅ Preview<br>✅ Development |

**Note:** This is used for Claude AI chat features. Keep this secret (backend-only).

#### Stripe Configuration

| Variable Name | Value | Where to Get It | Environments |
|---------------|-------|-----------------|--------------|
| `STRIPE_SECRET_KEY` | Test: `sk_test_...`<br>Live: `sk_live_...` | [Stripe Dashboard](https://dashboard.stripe.com/) → Developers → API keys | ⚠️ Use test keys for Preview/Dev<br>✅ Use live key for Production only |
| `STRIPE_WEBHOOK_SECRET` | `whsec_...` | [Stripe Dashboard](https://dashboard.stripe.com/) → Developers → Webhooks → Add endpoint | ✅ Production<br>✅ Preview (separate webhook)<br>✅ Development (separate webhook) |

**Important Notes:**
- Use **test mode** Stripe keys (`sk_test_...`) for Preview and Development environments
- Use **live mode** Stripe keys (`sk_live_...`) for Production only
- Create separate webhook endpoints for each environment:
  - Production: `https://bridebuddyv2.vercel.app/api/stripe-webhook`
  - Preview: `https://bridebuddyv2-git-[branch].vercel.app/api/stripe-webhook`

### Step 3: Configure Environment Scope

For each variable:
1. Click **Add Environment Variable**
2. Enter the **Name** (exact spelling, case-sensitive)
3. Enter the **Value**
4. Select environments:
   - ✅ **Production**
   - ✅ **Preview**
   - ✅ **Development**
5. Click **Save**

### Step 4: Verify Build Configuration

Vercel automatically runs the `build` script from `package.json` during deployment:

```json
{
  "scripts": {
    "build": "npm run build:config"
  }
}
```

This generates `public/js/config.js` from the environment variables, making Supabase credentials available to the frontend.

## Local Development Setup

### Step 1: Create .env File

```bash
cp .env.example .env
```

### Step 2: Fill in Environment Variables

Edit `.env` and replace all placeholder values with your actual credentials:

```bash
# Supabase
SUPABASE_URL=https://nluvnjydydotsrpluhey.supabase.co
SUPABASE_ANON_KEY=your_actual_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_actual_service_role_key_here

# Anthropic
ANTHROPIC_API_KEY=your_actual_anthropic_key_here

# Stripe (use TEST keys for local development)
STRIPE_SECRET_KEY=sk_test_your_test_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here
```

### Step 3: Generate config.js

```bash
npm run build:config
```

This creates `public/js/config.js` (gitignored).

### Step 4: Start Development Server

```bash
npm run dev
```

This runs `build:config` and starts the preview server at `http://localhost:4173`.

## Troubleshooting

### Error: "SUPABASE_URL is not set"

**Cause:** Environment variables not set correctly

**Fix for Local Development:**
```bash
# Verify .env file exists
cat .env

# Re-generate config.js
npm run build:config
```

**Fix for Vercel:**
1. Go to Vercel Dashboard → Settings → Environment Variables
2. Verify `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set for all environments
3. Redeploy: **Deployments** → **⋯** → **Redeploy**

### Error: "Failed to resolve module specifier './config.js'"

**Cause:** `config.js` file not generated

**Fix:**
```bash
# Generate the file
npm run build:config

# Verify it exists
ls -la public/js/config.js
```

### Error: "Supabase SDK not loaded"

**Cause:** Race condition - module script runs before Supabase CDN loads

**Fix:** This will be addressed in future updates. Current workaround:
1. Refresh the page
2. Check browser console for CDN loading errors

### Stripe Webhook Not Working

**Cause:** Webhook secret doesn't match environment

**Fix:**
1. Go to [Stripe Dashboard](https://dashboard.stripe.com/) → Developers → Webhooks
2. Create separate webhook endpoints for each environment:
   - Production: `https://bridebuddyv2.vercel.app/api/stripe-webhook`
   - Preview: `https://bridebuddyv2-git-main.vercel.app/api/stripe-webhook`
3. Copy the signing secret for each webhook
4. Set `STRIPE_WEBHOOK_SECRET` in Vercel environment variables for each environment

### Vercel Build Failing

**Check Build Logs:**
1. Go to Vercel Dashboard → Deployments
2. Click on failed deployment
3. View build logs

**Common Issues:**
- Missing environment variables → Add them in Vercel dashboard
- Build script failing → Check `scripts/build-config.js` for errors
- `npm install` failing → Check `package.json` dependencies

## Security Best Practices

### ✅ DO:
- Store all secrets in Vercel environment variables
- Use test Stripe keys for Preview/Development
- Keep `SUPABASE_SERVICE_ROLE_KEY` secret (backend-only)
- Add `.env` to `.gitignore` (already done)
- Regenerate keys if accidentally committed

### ❌ DON'T:
- Commit `.env` file to git
- Commit `public/js/config.js` to git
- Use production Stripe keys in Preview/Development
- Share service role keys publicly
- Hardcode secrets in source code

## Required Webhooks

### Stripe Webhooks

**Endpoint URL:** `https://your-domain.vercel.app/api/stripe-webhook`

**Events to Listen For:**
- `checkout.session.completed` - When user completes payment
- `customer.subscription.created` - When subscription created
- `customer.subscription.updated` - When subscription updated
- `customer.subscription.deleted` - When subscription cancelled

## Environment Variable Checklist

Before deploying, verify all variables are set:

**Vercel Dashboard:**
- [ ] `SUPABASE_URL` (Production, Preview, Development)
- [ ] `SUPABASE_ANON_KEY` (Production, Preview, Development)
- [ ] `SUPABASE_SERVICE_ROLE_KEY` (Production, Preview, Development)
- [ ] `ANTHROPIC_API_KEY` (Production, Preview, Development)
- [ ] `STRIPE_SECRET_KEY` (Production: live key, Preview/Dev: test key)
- [ ] `STRIPE_WEBHOOK_SECRET` (Separate secret for each environment)

**Local Development:**
- [ ] `.env` file created from `.env.example`
- [ ] All placeholder values replaced with real credentials
- [ ] `npm run build:config` executed successfully
- [ ] `public/js/config.js` generated

## Additional Resources

- [Vercel Environment Variables Docs](https://vercel.com/docs/projects/environment-variables)
- [Supabase API Settings](https://app.supabase.com/project/_/settings/api)
- [Anthropic API Keys](https://console.anthropic.com/)
- [Stripe API Keys](https://dashboard.stripe.com/apikeys)
- [Stripe Webhooks](https://dashboard.stripe.com/webhooks)

## Support

If you encounter issues not covered in this guide:
1. Check browser console for JavaScript errors
2. Check Vercel build logs for deployment errors
3. Verify all environment variables are set correctly
4. Ensure you're using the latest code from the repository

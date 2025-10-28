# Bride Buddy

An AI-powered wedding planning assistant that combines luxury design with intelligent technology. Bride Buddy helps couples plan their perfect wedding through an intuitive interface powered by Claude AI, with real-time collaboration, role-based access, and subscription management.

## Quick Start

### 1. Environment Setup

**IMPORTANT**: Before running the application, you must configure environment variables.

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Fill in all required values in `.env`:
   - Supabase credentials (URL, anon key, service role key)
   - Anthropic API key (for Claude AI chat)
   - Stripe keys (for payment processing)

3. See **[ENVIRONMENT.md](./ENVIRONMENT.md)** for detailed documentation on each variable and how to obtain them.

### 2. Generate Client Configuration

Generate the client-side configuration file from your environment variables:

```bash
npm run build:config
```

This creates `/public/js/config.js` (gitignored) containing your Supabase credentials for the frontend.

### 3. Start Development Server

```bash
npm run dev
```

This runs the build:config script and starts the preview server at `http://localhost:4173`.

Alternatively, run commands separately:
```bash
npm run build:config
npm run preview
```

### Local Development vs. Production Parity

**IMPORTANT**: The local preview server (`preview.js`) is designed for rapid local development only. It intentionally lacks production features to keep it simple and fast:

- **No HTTPS** - Serves over HTTP only
- **No compression** - Assets are served uncompressed (no gzip/brotli)
- **No caching headers** - No Cache-Control, ETag, or Last-Modified headers
- **No security headers** - Missing CSP, CORS, X-Frame-Options, etc.

**Production Testing Recommendation**: Always test security-critical features (CSP, CORS, authentication flows, Stripe webhooks) directly on Vercel preview deployments. Production parity issues cannot be caught with the local preview server.

Deploy to Vercel for every PR and test there before merging to catch environment-specific issues early:
```bash
git push origin your-branch
# Vercel will automatically create a preview deployment
# Test CSP, CORS, HTTPS, and compression on the preview URL
```

### Vercel Deployment

**See [VERCEL_SETUP.md](./VERCEL_SETUP.md) for complete deployment instructions.**

Quick checklist:
1. Set environment variables in Vercel Dashboard (Settings → Environment Variables)
2. Required variables: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `ANTHROPIC_API_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
3. Push to GitHub - Vercel auto-deploys
4. Build command automatically runs: `npm run build` (generates config.js)

## Development Scripts

### Quality Assurance

```bash
npm run lint           # Run ESLint on all JavaScript files
npm run lint:fix       # Auto-fix ESLint issues where possible
npm run validate       # Validate project structure and required files
npm run security:check # Check for hardcoded secrets and run npm audit
npm run ci:checks      # Run all CI checks (lint + validate + security)
```

### Continuous Integration

All pull requests and pushes automatically run:
- **ESLint** - Code quality and consistency checks
- **Structure validation** - Ensures required files/directories exist
- **Security scanning** - Detects hardcoded secrets and vulnerable dependencies
- **Vercel build validation** - Verifies deployment configuration

See `.github/workflows/ci.yml` for the complete CI pipeline.

## Project Structure

```
bridebuddyv2/
├── api/                      # Vercel serverless functions
│   ├── chat.js              # Main AI chat endpoint
│   ├── bestie-chat.js       # Bestie mode chat
│   ├── create-checkout.js   # Stripe checkout
│   ├── stripe-webhook.js    # Stripe webhook handler
│   └── ...
├── public/                   # Frontend assets
│   ├── css/                 # Stylesheets
│   ├── js/
│   │   ├── shared.js        # Common utilities
│   │   └── config.js        # Generated config (gitignored)
│   └── *.html               # Application pages
├── scripts/
│   └── build-config.js      # Generate config from .env
├── .env.example             # Environment variables template
├── ENVIRONMENT.md           # Detailed environment documentation
└── README.md                # This file
```

## Documentation

- **[VERCEL_SETUP.md](./VERCEL_SETUP.md)** - Complete Vercel deployment and environment variable setup guide
- **[ENVIRONMENT.md](./ENVIRONMENT.md)** - Complete guide to environment variables and secrets management
- **[TECHNICAL_ARCHITECTURE_REVIEW.md](./TECHNICAL_ARCHITECTURE_REVIEW.md)** - Technical architecture overview
- **[RLS_POLICY_GUIDE.md](./RLS_POLICY_GUIDE.md)** - Row Level Security policies guide

## Key Features

- AI-powered wedding planning chat (Claude)
- Real-time collaboration with role-based access
- Subscription management with Stripe
- Bestie mode for surprise planning
- Invite system for wedding party members
- Secure authentication with Supabase

## Troubleshooting

### "Failed to resolve module specifier './config.js'"

**Cause:** The `config.js` file hasn't been generated.

**Fix:**
```bash
# Make sure .env file exists with real values
cat .env

# Generate config.js
npm run build:config

# Verify it was created
ls -la public/js/config.js
```

### "SUPABASE_URL is not set in environment variables"

**Cause:** Missing environment variables.

**Fix for Local Development:**
```bash
# Copy template and fill in real values
cp .env.example .env
# Edit .env and add your Supabase credentials
npm run build:config
```

**Fix for Vercel:**
1. Go to Vercel Dashboard → Your Project → Settings → Environment Variables
2. Add `SUPABASE_URL` and `SUPABASE_ANON_KEY`
3. Redeploy the project

See **[VERCEL_SETUP.md](./VERCEL_SETUP.md)** for complete Vercel configuration instructions.

### Application Loads But Nothing Works

**Possible Causes:**
1. `config.js` contains placeholder values instead of real credentials
2. Supabase CDN script failed to load
3. JavaScript module errors

**Fix:**
```bash
# Verify config.js has real values (not placeholders)
cat public/js/config.js

# Check for "PLACEHOLDER" or "your_" in the file
grep -i "placeholder\|your_" public/js/config.js

# If placeholders found, update .env with real values and regenerate
npm run build:config
```

**Check Browser Console:**
1. Open browser DevTools (F12)
2. Go to Console tab
3. Look for errors related to:
   - Module loading failures
   - Supabase initialization errors
   - Network request failures

### Stripe Webhooks Not Working

See **[VERCEL_SETUP.md](./VERCEL_SETUP.md)** - Stripe Webhook section for detailed setup instructions.

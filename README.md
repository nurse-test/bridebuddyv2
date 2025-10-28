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

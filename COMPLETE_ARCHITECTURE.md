# 🏗️ BRIDE BUDDY V2 - COMPLETE ARCHITECTURE DIAGRAM

## 📊 YOUR ACTUAL STACK (Correct!)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER'S BROWSER                               │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Frontend (Static HTML/CSS/JS)                             │    │
│  │  - welcome-v2.html, dashboard-v2.html, bestie-v2.html      │    │
│  │  - Hosted on Vercel                                        │    │
│  │  - Uses @supabase/supabase-js client library               │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
         │                           │
         │ (1) Auth & Direct DB      │ (2) Chat Messages
         │     Queries               │     (via API)
         ▼                           ▼
┌──────────────────────┐    ┌──────────────────────────────┐
│   Supabase Auth      │    │   Vercel Serverless Functions│
│   - User signup      │    │   /api/*.js                  │
│   - User login       │    │                              │
│   - Session mgmt     │    │   ┌────────────────────┐    │
└──────────────────────┘    │   │ chat.js            │    │
         │                  │   │ - Gets user msg    │    │
         │                  │   │ - Fetches wedding  │    │
         │                  │   │ - Calls Claude API │────┼──┐
         ▼                  │   │ - Saves response   │    │  │
┌──────────────────────┐    │   └────────────────────┘    │  │
│  Supabase Database   │◄───┤                              │  │
│  (PostgreSQL + RLS)  │    │   ┌────────────────────┐    │  │
│                      │    │   │ bestie-chat.js     │    │  │
│  Tables:             │    │   │ - Gets bestie msg  │    │  │
│  - wedding_profiles  │    │   │ - Fetches wedding  │    │  │
│  - wedding_members   │    │   │ - Calls Claude API │────┼──┤
│  - chat_messages     │    │   │ - Saves response   │    │  │
│  - pending_updates   │    │   └────────────────────┘    │  │
│  - invite_codes      │    │                              │  │
│  - profiles          │    │   ┌────────────────────┐    │  │
│                      │◄───┤   │ create-wedding.js  │    │  │
│  24 RLS Policies ✅  │    │   │ - Creates wedding  │    │  │
└──────────────────────┘    │   └────────────────────┘    │  │
         ▲                  │                              │  │
         │                  │   ┌────────────────────┐    │  │
         │                  │   │ create-invite.js   │    │  │
         │                  │   │ - Gen invite code  │    │  │
         │                  │   └────────────────────┘    │  │
         │                  │                              │  │
         │                  │   ┌────────────────────┐    │  │
         │                  │   │ join-wedding.js    │    │  │
         │                  │   │ - Validate invite  │    │  │
         │                  │   └────────────────────┘    │  │
         │                  │                              │  │
         │                  │   ┌────────────────────┐    │  │
         │                  │   │ approve-update.js  │    │  │
         │                  │   │ - Approve/reject   │    │  │
         │                  │   └────────────────────┘    │  │
         │                  │                              │  │
         │                  │   ┌────────────────────┐    │  │
         │                  │   │ stripe-webhook.js  │    │  │
         └──────────────────┤   │ - Process payment  │    │  │
                            │   └────────────────────┘    │  │
                            │                              │  │
                            │   ┌────────────────────┐    │  │
                            │   │ create-checkout.js │    │  │
                            │   │ - Start payment    │────┼──┤
                            │   └────────────────────┘    │  │
                            └──────────────────────────────┘  │
                                                              │
                                                              │
    ┌─────────────────────────────────────────────────────────┘
    │
    │ (3) AI Chat Requests
    │     (POST with wedding context)
    ▼
┌──────────────────────────────────┐
│   Anthropic Claude API            │
│   https://api.anthropic.com       │
│                                   │
│   Model: claude-sonnet-4          │
│   - Extracts wedding data         │
│   - Natural conversation          │
│   - MOH/Best Man advice           │
└──────────────────────────────────┘
         │
         │ (4) AI Response
         │     (Text response)
         ▼
┌──────────────────────────────┐
│   Vercel Functions           │
│   - Parse AI response        │
│   - Extract structured data  │
│   - Save to database         │
└──────────────────────────────┘

┌──────────────────────────────┐
│   Stripe API                 │
│   - Payment processing       │
│   - Subscription management  │
│   - Webhooks                 │
└──────────────────────────────┘
         ▲
         │ (5) Payment Events
         │
    (from create-checkout.js
     and stripe-webhook.js)
```

---

## 🔄 COMPLETE DATA FLOW EXAMPLES

### **EXAMPLE 1: User Sends Chat Message (Main Wedding Planning)**

```
1. User types: "Our wedding is June 15, 2025 at Garden Villa"
   └─► dashboard-v2.html

2. Frontend calls Vercel function:
   └─► POST /api/chat
       Body: {
         message: "Our wedding is June 15...",
         userToken: "eyJhbG..."
       }

3. Vercel function (chat.js):
   ├─► Authenticates user via userToken
   ├─► Queries Supabase:
   │   └─► Get user's wedding_members → wedding_id
   │   └─► Get wedding_profiles data → Build context
   │
   ├─► Calls Claude API:
   │   └─► POST https://api.anthropic.com/v1/messages
   │       Headers: { x-api-key: ANTHROPIC_API_KEY }
   │       Body: {
   │         model: "claude-sonnet-4-20250514",
   │         messages: [{
   │           role: "user",
   │           content: "WEDDING CONTEXT + USER MESSAGE"
   │         }]
   │       }
   │
   ├─► Claude responds with:
   │   └─► <response>Great! I'll save that...</response>
   │       <extracted_data>
   │         { "wedding_date": "2025-06-15", "venue_name": "Garden Villa" }
   │       </extracted_data>
   │
   ├─► Parse Claude's response
   ├─► Save to Supabase:
   │   ├─► UPDATE wedding_profiles SET wedding_date='2025-06-15', venue_name='Garden Villa'
   │   ├─► INSERT into chat_messages (user message)
   │   └─► INSERT into chat_messages (assistant response)
   │
   └─► Return to frontend:
       { response: "Great! I'll save that..." }

4. Frontend displays AI response in chat UI
```

### **EXAMPLE 2: Bestie (MOH) Sends Chat Message**

```
1. MOH types: "Planning bachelorette party for 10 people"
   └─► bestie-v2.html

2. Frontend calls:
   └─► POST /api/bestie-chat
       Body: {
         message: "Planning bachelorette...",
         userToken: "eyJhbG..."
       }

3. Vercel function (bestie-chat.js):
   ├─► Authenticates user
   ├─► Queries Supabase for wedding context
   │
   ├─► Calls Claude API with BESTIE-SPECIFIC prompt:
   │   └─► POST https://api.anthropic.com/v1/messages
   │       Body: {
   │         model: "claude-sonnet-4-20250514",
   │         messages: [{
   │           role: "user",
   │           content: "You are Bestie Buddy, AI for MOH/Best Man..."
   │         }]
   │       }
   │
   ├─► Claude responds with bachelorette party advice
   │
   ├─► Save to Supabase:
   │   ├─► INSERT into chat_messages (message_type='bestie')
   │   └─► INSERT into chat_messages (assistant response, message_type='bestie')
   │
   └─► Return MOH-specific advice to frontend
```

### **EXAMPLE 3: Create Invite Code**

```
1. Owner clicks "Create Invite" → "Co-planner"
   └─► invite-v2.html

2. Frontend calls:
   └─► POST /api/create-invite
       Body: { userToken: "eyJ...", role: "member" }

3. Vercel function (create-invite.js):
   ├─► Authenticates user
   ├─► Verifies user is wedding owner
   ├─► Generates random code: "ABC12345"
   ├─► Saves to Supabase:
   │   └─► INSERT into invite_codes {
   │         code: "ABC12345",
   │         role: "member",
   │         wedding_id: "...",
   │         created_by: user_id
   │       }
   └─► Returns: { inviteCode: "ABC12345" }

4. Frontend displays code for user to share
```

---

## 🎯 WHERE CLAUDE FITS IN YOUR STACK

```
┌──────────────────────────────────────────────────────────┐
│                    CLAUDE'S ROLE                          │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Claude API is called FROM Vercel Functions:             │
│                                                           │
│  ┌─────────────────────────────────────────┐            │
│  │  api/chat.js                             │            │
│  │  - Wedding planning AI assistant         │            │
│  │  - Extracts dates, budgets, vendors      │            │
│  │  - Updates wedding_profiles              │            │
│  └─────────────────────────────────────────┘            │
│                                                           │
│  ┌─────────────────────────────────────────┐            │
│  │  api/bestie-chat.js                      │            │
│  │  - MOH/Best Man AI assistant             │            │
│  │  - Bachelorette/bridal shower advice     │            │
│  │  - Separate from main chat               │            │
│  └─────────────────────────────────────────┘            │
│                                                           │
│  Each chat message:                                      │
│  1. Frontend → Vercel function                           │
│  2. Vercel → Supabase (get wedding context)             │
│  3. Vercel → Claude API (with context + user message)   │
│  4. Claude → Vercel (AI response + extracted data)      │
│  5. Vercel → Supabase (save messages + update data)     │
│  6. Vercel → Frontend (show AI response)                │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## 🔐 ENVIRONMENT VARIABLES IN VERCEL

Your Vercel functions need these environment variables:

```bash
# Supabase Connection
SUPABASE_URL=https://nluvnjydydotsrpluhey.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...  # For user-authenticated queries
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...  # For admin operations

# Claude AI
ANTHROPIC_API_KEY=sk-ant-...  # For chat.js and bestie-chat.js

# Stripe Payments
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

---

## 📊 API CALL FLOW BREAKDOWN

### **Vercel Functions That DON'T Call Claude:**

```javascript
✅ create-wedding.js → Supabase only
✅ create-checkout.js → Stripe only
✅ stripe-webhook.js → Supabase only
✅ create-invite.js → Supabase only
✅ join-wedding.js → Supabase only
✅ approve-update.js → Supabase only
```

### **Vercel Functions That DO Call Claude:**

```javascript
🤖 chat.js → Supabase + Claude API
🤖 bestie-chat.js → Supabase + Claude API
```

---

## 💰 COST IMPLICATIONS

### **Claude API Costs:**

Every chat message costs:
- **Input tokens:** Wedding context (500-1000 tokens) + User message (~50-200 tokens)
- **Output tokens:** AI response (~200-500 tokens)

**Approximate cost per message:** $0.003 - $0.015

**From your code (api/chat.js:109):**
```javascript
{
  model: 'claude-sonnet-4-20250514',
  max_tokens: 2048,  // Max AI can respond with
  messages: [...]
}
```

---

## 🎯 KEY ARCHITECTURAL POINTS

1. **Vercel hosts everything:**
   - Static frontend (HTML/CSS/JS)
   - Serverless API functions (/api/*.js)

2. **Supabase provides:**
   - PostgreSQL database
   - User authentication
   - Row Level Security (RLS)

3. **Claude AI provides:**
   - Natural language understanding
   - Wedding data extraction
   - Conversational responses

4. **Stripe provides:**
   - Payment processing
   - Subscription management

5. **Data flow:**
   ```
   User → Frontend → Vercel Function → Claude API
                                     ↓
                           Response ← Claude
                                     ↓
                           Save → Supabase DB
                                     ↓
                           Display ← Frontend
   ```

---

## ✅ WHAT YOU DON'T NEED

- ❌ Supabase Edge Functions (you use Vercel functions)
- ❌ Deno runtime (Vercel uses Node.js)
- ❌ Supabase CLI for functions (only for database migrations)
- ❌ Separate backend server (Vercel functions ARE your backend)

---

## 📋 YOUR COMPLETE TECH STACK

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | HTML/CSS/Vanilla JS | User interface |
| **Hosting** | Vercel | Static site + serverless functions |
| **Backend** | Vercel Functions (Node.js) | API endpoints, business logic |
| **Database** | Supabase (PostgreSQL) | Data storage, RLS security |
| **Auth** | Supabase Auth | User signup/login |
| **AI** | Anthropic Claude Sonnet 4 | Chat intelligence |
| **Payments** | Stripe | Subscriptions, one-time payments |
| **Deployment** | Git → Vercel auto-deploy | CI/CD |

---

**Does this clarify where Claude fits in?** It's called from 2 Vercel functions (`chat.js` and `bestie-chat.js`) to power the AI conversations! 🤖

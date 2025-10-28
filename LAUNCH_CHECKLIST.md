# Bride Buddy - Quick Launch Checklist

**Status**: 🟡 Not Ready - 5 Critical Fixes Required

Last Updated: October 28, 2025

---

## 🔴 CRITICAL - Must Fix Before ANY Launch

### 1. Environment Configuration (30 min)

```bash
# Step 1: Create .env file
cp .env.example .env

# Step 2: Fill in these values in .env:
# - SUPABASE_URL=https://your-project.supabase.co
# - SUPABASE_ANON_KEY=eyJhbGci...
# - SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...
# - ANTHROPIC_API_KEY=sk-ant-api03-...
# - STRIPE_SECRET_KEY=sk_test_... (or sk_live_...)
# - STRIPE_WEBHOOK_SECRET=whsec_...

# Step 3: Generate config.js
npm run build:config

# Step 4: Verify
ls -la public/js/config.js  # Should exist
```

**Status**: ⬜ Not Done

---

### 2. Stripe Bestie Price IDs (15 min)

**File**: `public/subscribe-luxury.html` (lines 194-195)

```javascript
// BEFORE (broken):
'vip_bestie_monthly': 'price_YOUR_BESTIE_MONTHLY',
'vip_bestie_one_time': 'price_YOUR_BESTIE_ONETIME'

// AFTER (working):
'vip_bestie_monthly': 'price_1ABCD...',  // Your real Stripe price ID
'vip_bestie_one_time': 'price_1EFGH...'  // Your real Stripe price ID
```

**How to get price IDs**:
1. Go to https://dashboard.stripe.com/products
2. Create "VIP + Bestie Monthly" ($19.99/month recurring)
3. Create "VIP + Bestie Until I Do" ($149 one-time)
4. Copy price IDs and paste above

**Status**: ⬜ Not Done

---

### 3. Create Success Page (15 min)

**Missing**: `public/success.html`

**Quick Fix**:
```bash
# Copy this template or create your own
cat > public/success.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bride Buddy - Payment Successful</title>
    <link rel="stylesheet" href="/css/styles-luxury.css">
    <link rel="stylesheet" href="/css/components-luxury.css">
</head>
<body>
    <div class="bg-sunset">
        <div class="container" style="min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: var(--space-8);">
            <div class="card card-gold-accent" style="max-width: 600px; text-align: center;">
                <div style="font-size: 64px; margin-bottom: var(--space-4);">🎉</div>
                <h1 style="font-family: var(--font-heading); color: var(--color-gold); margin-bottom: var(--space-4);">
                    Welcome to VIP!
                </h1>
                <p style="font-size: var(--text-lg); margin-bottom: var(--space-6);">
                    Your payment was successful. All VIP features are now active!
                </p>
                <a href="dashboard-luxury.html" class="btn btn-primary btn-lg">
                    Go to Dashboard
                </a>
            </div>
        </div>
    </div>
    <script type="module">
        import { showToast } from '/js/shared.js';
        const sessionId = new URLSearchParams(window.location.search).get('session_id');
        if (sessionId) showToast('Payment successful! VIP features activated.', 'success');
    </script>
</body>
</html>
EOF
```

**Status**: ⬜ Not Done

---

### 4. Remove Console Logs (20 min)

**Option A - Quick** (remove all console.log, keep console.error):
```bash
# WARNING: Test after running this command
find public -name "*.html" -type f -exec sed -i.bak '/console\.log(/d' {} +
```

**Option B - Manual** (safer, review each one):
Edit these files and remove/comment console.log statements:
- `public/subscribe-luxury.html`
- `public/settings-luxury.html`
- `public/dashboard-luxury.html`
- `public/login-luxury.html`
- `public/notifications-luxury.html`
- `public/invite-luxury.html`

Keep `console.error()` for error tracking.

**Status**: ⬜ Not Done

---

### 5. Verify Stripe Webhook (10 min)

**Check**:
1. Go to https://dashboard.stripe.com/webhooks
2. Verify endpoint exists: `https://bridebuddyv2.vercel.app/api/stripe-webhook`
3. Events enabled:
   - ✅ `checkout.session.completed`
   - ✅ `customer.subscription.deleted`
4. Copy webhook secret to `STRIPE_WEBHOOK_SECRET` in .env

**Test**:
```bash
# Install Stripe CLI if needed
brew install stripe/stripe-cli/stripe

# Test locally
stripe listen --forward-to localhost:4173/api/stripe-webhook
stripe trigger checkout.session.completed
```

**Status**: ⬜ Not Done

---

## ⚠️ IMPORTANT - Should Do Today

### 6. Vercel Environment Variables (15 min)

1. Go to Vercel Dashboard > Your Project > Settings > Environment Variables
2. Add all variables from your local .env:
   - SUPABASE_URL
   - SUPABASE_ANON_KEY
   - SUPABASE_SERVICE_ROLE_KEY
   - ANTHROPIC_API_KEY
   - STRIPE_SECRET_KEY
   - STRIPE_WEBHOOK_SECRET
   - APP_URL (https://bridebuddyv2.vercel.app)
3. Set for: Production, Preview, Development
4. Redeploy application

**Status**: ⬜ Not Done

---

### 7. Database Verification (10 min)

1. Go to Supabase Dashboard > SQL Editor
2. Paste contents of `database_status_check.sql`
3. Execute
4. Verify all tables exist with RLS enabled
5. If any missing, run `database_init.sql`

**Key tables to check**:
- wedding_profiles
- wedding_members
- vendor_tracker
- budget_tracker
- wedding_tasks
- bestie_profile
- chat_messages
- invite_codes

**Status**: ⬜ Not Done

---

### 8. Test Full Payment Flow (20 min)

Test each plan:
- [ ] VIP Monthly ($12.99/month) - Test mode card: 4242 4242 4242 4242
- [ ] VIP One-Time ($99)
- [ ] VIP + Bestie Monthly ($19.99/month)
- [ ] VIP + Bestie One-Time ($149)

Verify for each:
- [ ] Stripe checkout loads
- [ ] Payment completes
- [ ] Redirects to success.html
- [ ] Webhook updates is_vip in database
- [ ] User can access VIP features

**Status**: ⬜ Not Done

---

## ✅ OPTIONAL - Can Do Post-Launch

### 9. Create Paywall Page (10 min)
Create `public/paywall.html` (Stripe cancel redirect)

**Status**: ⬜ Not Done

---

### 10. Error Pages (15 min)
- Create `public/404.html`
- Create `public/500.html`

**Status**: ⬜ Not Done

---

### 11. Restrict CORS (5 min)
Update `vercel.json:27` to restrict to your domain

**Status**: ⬜ Not Done

---

### 12. Add Monitoring (30 min)
Set up Sentry or LogRocket for error tracking

**Status**: ⬜ Not Done

---

## 📊 Progress Tracker

**Critical Tasks**: 0 / 5 Complete (🔴 Blocking)
**Important Tasks**: 0 / 3 Complete (⚠️ Should do today)
**Optional Tasks**: 0 / 4 Complete (✅ Can wait)

**Estimated Time to Launch**: 2-3 hours

---

## 🚀 Launch Command

**After completing critical tasks**:

```bash
# 1. Final verification
npm run build:config
npm run dev
# Test in browser: http://localhost:4173

# 2. Commit changes
git add .
git commit -m "Pre-launch fixes: env config, Stripe price IDs, success page, console cleanup"
git push origin <your-branch>

# 3. Deploy to Vercel
# Vercel will auto-deploy on push, or manually deploy via dashboard

# 4. Post-deployment checks
# - Visit https://bridebuddyv2.vercel.app
# - Test signup flow
# - Test payment flow
# - Check Vercel logs for errors
```

---

## 🆘 Quick Help

**Config.js not generating?**
```bash
# Check .env exists and has values
cat .env | grep SUPABASE_URL
# Should show: SUPABASE_URL=https://...

# Regenerate
npm run build:config
```

**Stripe webhook not receiving events?**
```bash
# Check webhook secret is correct
echo $STRIPE_WEBHOOK_SECRET  # Local
# Check Vercel dashboard for production

# Test locally
stripe listen --forward-to localhost:4173/api/stripe-webhook
```

**Database not working?**
```bash
# Verify RLS policies in Supabase Dashboard > Authentication > Policies
# Re-run migrations if needed
```

---

## 📞 Support

- Full audit: `PRE_LAUNCH_AUDIT_REPORT.md`
- Environment help: `ENVIRONMENT.md`
- Architecture: `TECHNICAL_ARCHITECTURE_REVIEW.md`
- README: `README.md`

---

**Ready to Launch?** Complete items 1-5 above, then test thoroughly!

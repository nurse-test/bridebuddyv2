# Vercel Environment Variables Setup

## CRITICAL: Missing Environment Variables

The invite acceptance flow is failing with:
**Error:** "No API key found in request" - "No `apikey` request header or url param was found."

This means the Supabase environment variables are **not set in Vercel**.

## Required Environment Variables

Go to **Vercel Dashboard → Your Project → Settings → Environment Variables** and add:

### 1. SUPABASE_URL
```
Value: https://nluvnjydydotsrpluhey.supabase.co
Environments: Production, Preview, Development
```

### 2. SUPABASE_ANON_KEY
```
Value: [Your Supabase Anon Key]
Environments: Production, Preview, Development
```
**Get from:** Supabase Dashboard → Project Settings → API → `anon` `public`

### 3. SUPABASE_SERVICE_ROLE_KEY (CRITICAL!)
```
Value: [Your Supabase Service Role Key]
Environments: Production, Preview, Development
```
**Get from:** Supabase Dashboard → Project Settings → API → `service_role` `secret`

⚠️ **WARNING:** This key bypasses Row Level Security - keep it secret!

### 4. ANTHROPIC_API_KEY (For chat features)
```
Value: [Your Anthropic API Key]
Environments: Production, Preview, Development
```
**Get from:** https://console.anthropic.com/

### 5. STRIPE_SECRET_KEY (For payments)
```
Value: [Your Stripe Secret Key]
Environments: Production, Preview, Development
```
**Get from:** Stripe Dashboard → Developers → API keys

### 6. STRIPE_WEBHOOK_SECRET (For webhooks)
```
Value: [Your Stripe Webhook Secret]
Environments: Production, Preview, Development
```
**Get from:** Stripe Dashboard → Developers → Webhooks

## How to Add Environment Variables in Vercel

1. Go to https://vercel.com/dashboard
2. Select your project (`bridebuddyv2`)
3. Go to **Settings** tab
4. Click **Environment Variables** in the sidebar
5. Click **Add New**
6. Enter **Name** (e.g., `SUPABASE_URL`)
7. Enter **Value** (paste your actual value)
8. Select **Environments**: Check all three (Production, Preview, Development)
9. Click **Save**
10. Repeat for all variables above

## After Adding Variables

**CRITICAL:** You MUST redeploy for changes to take effect!

### Option 1: Redeploy via Vercel Dashboard
1. Go to **Deployments** tab
2. Click on the latest deployment
3. Click **⋯** (three dots)
4. Click **Redeploy**

### Option 2: Redeploy via Git
```bash
git commit --allow-empty -m "Trigger redeploy after env vars"
git push
```

## Verify Environment Variables are Set

After redeploying, check the deployment logs:
1. Go to **Deployments** tab
2. Click on the latest deployment
3. Click **Runtime Logs**
4. You should NOT see any "undefined" or "missing API key" errors

## Testing

After environment variables are set and redeployed:
1. Create a new invite link
2. Open in incognito window
3. Create a new account
4. Check browser console (F12)
5. You should see:
   ```
   ✅ [ACCEPT-INVITE] User authenticated
   ✅ [ACCEPT-INVITE] Invite found
   ✅ [ACCEPT-INVITE] User added to wedding_members successfully
   ```

## Common Issues

### "No API key found"
- Environment variables not set in Vercel
- **Solution:** Add all variables and redeploy

### Variables showing as "undefined"
- Variables set but not redeployed
- **Solution:** Redeploy the project

### Service role key not working
- Using anon key instead of service role key
- **Solution:** Double-check you copied the `service_role` key, not `anon` key

### Still not working after setting variables
- Environment variables only apply to NEW deployments
- **Solution:** Force a redeploy (see "After Adding Variables" above)

## Security Notes

⚠️ **NEVER commit these values to Git!**
- Keep `.env` in `.gitignore`
- Only set values in Vercel Dashboard
- Service role key bypasses all security - keep secret!

## Need Help?

If you're still seeing the error after:
1. Adding all environment variables
2. Redeploying the project
3. Clearing browser cache

Check the Vercel deployment logs for specific errors.

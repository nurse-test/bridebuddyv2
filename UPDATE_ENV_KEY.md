# UPDATE YOUR SUPABASE KEY

## Current Status
Your .env file has: `PLACEHOLDER_REPLACE_WITH_REAL_KEY`

## What You Need To Do

1. **Get your Supabase anon key:**
   - Go to: https://app.supabase.com/project/nluvnjydydotsrpluhey/settings/api
   - Look for the "anon" "public" key
   - It looks like: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS...` (very long)
   - Copy the ENTIRE key

2. **Open .env file:**
   ```bash
   nano .env
   ```
   OR use your favorite text editor

3. **Find this line:**
   ```
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5sdXZuanlkeWRvdHNycGx1aGV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzAwNDk2MDAsImV4cCI6MjA0NTYyNTYwMH0.PLACEHOLDER_REPLACE_WITH_REAL_KEY
   ```

4. **Replace EVERYTHING after `SUPABASE_ANON_KEY=` with your real key:**
   ```
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5sdXZuanlkeWRvdHNycGx1aGV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzE4NjcyMDAsImV4cCI6MjA0NzQ0MzIwMH0.YOUR_REAL_KEY_HERE
   ```

5. **Save and exit**
   - If using nano: Press `Ctrl+X`, then `Y`, then `Enter`

6. **Regenerate config.js:**
   ```bash
   npm run build:config
   ```

7. **Start the server:**
   ```bash
   npm run dev
   ```

8. **Open browser:**
   ```
   http://localhost:4173
   ```

## How to Check if Your Key is Real

A real Supabase anon key:
- ✅ Starts with `eyJhbGci`
- ✅ Has THREE parts separated by dots (`.`)
- ✅ Is very long (200+ characters)
- ✅ Does NOT contain the word "PLACEHOLDER"
- ✅ Does NOT contain the word "your_"

## Still Stuck?

If you can't find your Supabase key:
1. Make sure you're logged into https://app.supabase.com
2. Make sure you're viewing the correct project
3. The key is on the "API" page under "Project API keys"
4. You want the "anon" "public" key (NOT the service_role key for now)

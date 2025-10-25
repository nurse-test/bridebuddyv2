# Migration 007: Add Missing Wedding Profile Columns

## Problem

The frontend and API code expect subscription and wedding data columns that don't exist in the `wedding_profiles` table:

**Missing Subscription Columns:**
- `trial_start_date`
- `trial_end_date`
- `plan_type`
- `subscription_status`
- `bestie_addon_enabled`
- `is_vip`
- `stripe_customer_id`
- `stripe_subscription_id`

**Missing Wedding Data Columns:**
- `wedding_name`, `partner1_name`, `partner2_name`
- `wedding_date`, `wedding_time`
- `ceremony_location`, `reception_location`
- `venue_name`, `venue_cost`
- `expected_guest_count`, `total_budget`
- `wedding_style`, `color_scheme_primary`

**Missing Vendor Columns:**
- `photographer_name`, `photographer_cost`
- `caterer_name`, `caterer_cost`
- `florist_name`, `florist_cost`
- `dj_band_name`, `dj_band_cost`
- `baker_name`, `cake_flavors`

## Solution

Run migration 007 to add all missing columns to the database.

## How to Apply

### Option 1: Run Standalone Migration (Recommended)

1. Open Supabase Dashboard
2. Go to SQL Editor
3. Open `/migrations/007_add_missing_wedding_profile_columns.sql`
4. Copy the entire contents
5. Paste into SQL Editor
6. Click "Run"

### Option 2: Run Full Database Init (For New Databases)

1. Open Supabase Dashboard
2. Go to SQL Editor
3. Open `/database_init.sql`
4. Copy the entire contents
5. Paste into SQL Editor
6. Click "Run"

This will create all tables and apply all migrations including 007.

## Verification

After running the migration, verify all columns exist:

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'wedding_profiles'
ORDER BY ordinal_position;
```

You should see **35 columns** total including all subscription, wedding data, and vendor fields.

## What Changed in the Code

### api/create-wedding.js

**Before:** Stripped down to minimal fields
```javascript
const weddingData = {
  owner_id: userId
};
```

**After:** Full subscription support restored
```javascript
const weddingData = {
  owner_id: userId,
  trial_start_date: new Date().toISOString(),
  trial_end_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
  plan_type: 'trial',
  subscription_status: 'trialing',
  bestie_addon_enabled: true,
  is_vip: false
};
```

## Features Enabled

After this migration, the following features will work:

✅ 7-day free trial for new weddings
✅ Subscription status tracking
✅ Bestie addon functionality
✅ Wedding details storage (venue, budget, guest count)
✅ Vendor information tracking
✅ Stripe integration (customer ID, subscription ID)
✅ VIP accounts

## Safe to Re-Run

This migration uses `IF NOT EXISTS` checks, so it's safe to run multiple times. It will only add columns that don't already exist.

## Next Steps

After applying this migration:

1. Test wedding creation in onboarding flow
2. Verify trial dates are set correctly
3. Test bestie addon features
4. Verify Stripe webhook updates work

## Related Files

- `migrations/007_add_missing_wedding_profile_columns.sql` - Standalone migration
- `database_init.sql` - Updated master init script (includes migration 007)
- `api/create-wedding.js` - Restored subscription fields
- `SCHEMA_RLS_ANALYSIS.md` - Full schema documentation

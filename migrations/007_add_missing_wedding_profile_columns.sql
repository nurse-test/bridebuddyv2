-- ============================================================================
-- MIGRATION 007: Add Missing wedding_profiles Columns
-- ============================================================================
-- This migration adds all the subscription, wedding data, and vendor columns
-- that the application expects but may be missing from the database.
--
-- SAFE TO RE-RUN: Uses IF NOT EXISTS checks
-- ============================================================================

-- ============================================================================
-- STEP 1: Create wedding_profiles table if it doesn't exist
-- ============================================================================

CREATE TABLE IF NOT EXISTS wedding_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS wedding_profiles_owner_id_idx ON wedding_profiles(owner_id);
CREATE INDEX IF NOT EXISTS wedding_profiles_created_at_idx ON wedding_profiles(created_at DESC);

-- ============================================================================
-- STEP 2: Create wedding_members table if it doesn't exist
-- ============================================================================

CREATE TABLE IF NOT EXISTS wedding_members (
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'member', 'bestie')),
  PRIMARY KEY (wedding_id, user_id)
);

CREATE INDEX IF NOT EXISTS wedding_members_user_id_idx ON wedding_members(user_id);
CREATE INDEX IF NOT EXISTS wedding_members_wedding_id_idx ON wedding_members(wedding_id);

-- ============================================================================
-- STEP 3: Add basic wedding information columns
-- ============================================================================

DO $$
BEGIN
  -- Wedding basic info
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'wedding_name') THEN
    ALTER TABLE wedding_profiles ADD COLUMN wedding_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'partner1_name') THEN
    ALTER TABLE wedding_profiles ADD COLUMN partner1_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'partner2_name') THEN
    ALTER TABLE wedding_profiles ADD COLUMN partner2_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'wedding_date') THEN
    ALTER TABLE wedding_profiles ADD COLUMN wedding_date DATE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'wedding_time') THEN
    ALTER TABLE wedding_profiles ADD COLUMN wedding_time TIME;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'ceremony_location') THEN
    ALTER TABLE wedding_profiles ADD COLUMN ceremony_location TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'reception_location') THEN
    ALTER TABLE wedding_profiles ADD COLUMN reception_location TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'venue_name') THEN
    ALTER TABLE wedding_profiles ADD COLUMN venue_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'venue_cost') THEN
    ALTER TABLE wedding_profiles ADD COLUMN venue_cost NUMERIC(10, 2);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'expected_guest_count') THEN
    ALTER TABLE wedding_profiles ADD COLUMN expected_guest_count INTEGER;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'total_budget') THEN
    ALTER TABLE wedding_profiles ADD COLUMN total_budget NUMERIC(10, 2);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'wedding_style') THEN
    ALTER TABLE wedding_profiles ADD COLUMN wedding_style TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'color_scheme_primary') THEN
    ALTER TABLE wedding_profiles ADD COLUMN color_scheme_primary TEXT;
  END IF;
END $$;

-- ============================================================================
-- STEP 4: Add vendor information columns
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'photographer_name') THEN
    ALTER TABLE wedding_profiles ADD COLUMN photographer_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'photographer_cost') THEN
    ALTER TABLE wedding_profiles ADD COLUMN photographer_cost NUMERIC(10, 2);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'caterer_name') THEN
    ALTER TABLE wedding_profiles ADD COLUMN caterer_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'caterer_cost') THEN
    ALTER TABLE wedding_profiles ADD COLUMN caterer_cost NUMERIC(10, 2);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'florist_name') THEN
    ALTER TABLE wedding_profiles ADD COLUMN florist_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'florist_cost') THEN
    ALTER TABLE wedding_profiles ADD COLUMN florist_cost NUMERIC(10, 2);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'dj_band_name') THEN
    ALTER TABLE wedding_profiles ADD COLUMN dj_band_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'dj_band_cost') THEN
    ALTER TABLE wedding_profiles ADD COLUMN dj_band_cost NUMERIC(10, 2);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'baker_name') THEN
    ALTER TABLE wedding_profiles ADD COLUMN baker_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'cake_flavors') THEN
    ALTER TABLE wedding_profiles ADD COLUMN cake_flavors TEXT;
  END IF;
END $$;

-- ============================================================================
-- STEP 5: Add subscription and business columns
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'trial_start_date') THEN
    ALTER TABLE wedding_profiles ADD COLUMN trial_start_date TIMESTAMPTZ;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'trial_end_date') THEN
    ALTER TABLE wedding_profiles ADD COLUMN trial_end_date TIMESTAMPTZ;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'plan_type') THEN
    ALTER TABLE wedding_profiles ADD COLUMN plan_type TEXT CHECK (plan_type IN ('trial', 'free', 'basic', 'premium', 'enterprise'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'subscription_status') THEN
    ALTER TABLE wedding_profiles ADD COLUMN subscription_status TEXT CHECK (subscription_status IN ('trialing', 'active', 'past_due', 'canceled', 'unpaid'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'bestie_addon_enabled') THEN
    ALTER TABLE wedding_profiles ADD COLUMN bestie_addon_enabled BOOLEAN DEFAULT FALSE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'is_vip') THEN
    ALTER TABLE wedding_profiles ADD COLUMN is_vip BOOLEAN DEFAULT FALSE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'stripe_customer_id') THEN
    ALTER TABLE wedding_profiles ADD COLUMN stripe_customer_id TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'stripe_subscription_id') THEN
    ALTER TABLE wedding_profiles ADD COLUMN stripe_subscription_id TEXT;
  END IF;
END $$;

-- ============================================================================
-- STEP 6: Add timestamp columns if missing
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'created_at') THEN
    ALTER TABLE wedding_profiles ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wedding_profiles' AND column_name = 'updated_at') THEN
    ALTER TABLE wedding_profiles ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
END $$;

-- ============================================================================
-- STEP 7: Create trigger for updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_wedding_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_wedding_profiles_updated_at ON wedding_profiles;

CREATE TRIGGER trigger_update_wedding_profiles_updated_at
  BEFORE UPDATE ON wedding_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_wedding_profiles_updated_at();

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check all columns exist
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'wedding_profiles'
ORDER BY ordinal_position;

-- Expected columns:
-- id, owner_id, wedding_name, partner1_name, partner2_name, wedding_date,
-- wedding_time, ceremony_location, reception_location, venue_name, venue_cost,
-- expected_guest_count, total_budget, wedding_style, color_scheme_primary,
-- photographer_name, photographer_cost, caterer_name, caterer_cost,
-- florist_name, florist_cost, dj_band_name, dj_band_cost, baker_name,
-- cake_flavors, trial_start_date, trial_end_date, plan_type,
-- subscription_status, bestie_addon_enabled, is_vip, stripe_customer_id,
-- stripe_subscription_id, created_at, updated_at

SELECT
  '✓✓✓ MIGRATION 007 COMPLETE' as status,
  'wedding_profiles table now has all required columns' as message;

-- ============================================================================
-- COMPLETE
-- ============================================================================

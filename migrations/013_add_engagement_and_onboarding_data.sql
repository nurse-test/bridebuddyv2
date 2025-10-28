-- ============================================================================
-- MIGRATION 008: Add Engagement Date and Onboarding Data
-- ============================================================================
-- Adds columns to store onboarding data collected during signup
-- ============================================================================

-- Add engagement date column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'wedding_profiles' AND column_name = 'engagement_date'
  ) THEN
    ALTER TABLE wedding_profiles ADD COLUMN engagement_date DATE;
  END IF;
END $$;

-- Add started_planning column (tracks if they answered "yes" to planning)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'wedding_profiles' AND column_name = 'started_planning'
  ) THEN
    ALTER TABLE wedding_profiles ADD COLUMN started_planning BOOLEAN DEFAULT false;
  END IF;
END $$;

-- Add planning_completed column (stores array of completed planning items)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'wedding_profiles' AND column_name = 'planning_completed'
  ) THEN
    ALTER TABLE wedding_profiles ADD COLUMN planning_completed JSONB DEFAULT '[]'::jsonb;
  END IF;
END $$;

-- Add index on engagement_date for sorting/filtering
CREATE INDEX IF NOT EXISTS wedding_profiles_engagement_date_idx
ON wedding_profiles(engagement_date);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT
  '✓ Migration 008 Complete' as status,
  'Added engagement_date, started_planning, planning_completed columns' as changes;

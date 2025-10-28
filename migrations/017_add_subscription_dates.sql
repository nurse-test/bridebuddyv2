-- ============================================================================
-- Migration 017: Add Subscription Date Tracking
-- ============================================================================
-- Purpose: Add subscription_start_date and subscription_end_date columns
--          to wedding_profiles table for better subscription management
-- Date: 2025-10-28
-- ============================================================================

-- Add subscription date columns to wedding_profiles
ALTER TABLE wedding_profiles
ADD COLUMN IF NOT EXISTS subscription_start_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMPTZ;

-- Add comment for documentation
COMMENT ON COLUMN wedding_profiles.subscription_start_date IS 'When the paid subscription started (null for trial/free)';
COMMENT ON COLUMN wedding_profiles.subscription_end_date IS 'When the subscription expires (for "Until I Do" plans, set to wedding_date)';

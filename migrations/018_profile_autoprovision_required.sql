-- ============================================================================
-- MIGRATION 018: Profile Auto-Provisioning (REQUIRED)
-- ============================================================================
-- Purpose: Ensure reliable profile creation for all new user signups
-- Status: REQUIRED - Critical for data integrity and proper user onboarding
--
-- This migration establishes the foundational trigger mechanism that
-- automatically creates profile records when users sign up through Supabase Auth.
-- Without this trigger, new environments may experience failures during signup
-- flows, invitation acceptance, and wedding creation.
--
-- DEPLOYMENT REQUIREMENT: This migration MUST be applied to all environments
-- (development, staging, production) to ensure consistent behavior.
-- ============================================================================

-- ============================================================================
-- STEP 1: Create or replace the profile auto-provisioning function
-- ============================================================================
-- This function is invoked automatically after each user signup.
-- It extracts user metadata and creates a corresponding profile record.
--
-- Key features:
-- - Extracts email directly from auth.users
-- - Extracts full_name from raw_user_meta_data JSONB field
-- - Uses ON CONFLICT to safely handle duplicate creation attempts
-- - SECURITY DEFINER allows the function to write to profiles table
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  )
  ON CONFLICT (id) DO NOTHING;  -- Prevents errors if profile already exists
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 2: Create the trigger on auth.users table
-- ============================================================================
-- This trigger fires AFTER each INSERT on the auth.users table.
-- Timing: AFTER INSERT ensures the user record is fully committed before
-- attempting to create the profile record.
-- ============================================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- VERIFICATION QUERY (Run manually to confirm trigger is active)
-- ============================================================================
-- SELECT
--   trigger_name,
--   event_manipulation,
--   event_object_table,
--   action_statement
-- FROM information_schema.triggers
-- WHERE trigger_name = 'on_auth_user_created';
--
-- Expected result:
--   trigger_name: on_auth_user_created
--   event_manipulation: INSERT
--   event_object_table: users
--   action_statement: EXECUTE FUNCTION public.handle_new_user()
-- ============================================================================

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
--
-- WHY THIS IS REQUIRED:
-- ----------------------
-- 1. Defense-in-depth: Even though API endpoints may check for profiles,
--    the database should enforce data integrity at the lowest level
-- 2. Consistency: Ensures profiles exist immediately after signup, before
--    any application code runs
-- 3. Reliability: Protects against edge cases where API profile creation
--    might be skipped or fail
-- 4. New environments: Critical for clean deployments where no fallback
--    profile creation logic exists yet
--
-- RELATIONSHIP TO MIGRATION 016:
-- -------------------------------
-- Migration 016 was marked as "OPTIONAL" and served as a backup mechanism.
-- This migration (018) supersedes 016 and establishes profile auto-provisioning
-- as a REQUIRED component of the database schema.
--
-- The ON CONFLICT clause ensures this works harmoniously with any application-
-- level profile creation, preventing errors if both paths execute.
--
-- SAFE TO RE-RUN:
-- ---------------
-- Yes. Uses CREATE OR REPLACE for the function and DROP TRIGGER IF EXISTS
-- for the trigger, making this migration fully idempotent.
--
-- ============================================================================

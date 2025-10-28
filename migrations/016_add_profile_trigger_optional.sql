-- ============================================================================
-- MIGRATION 016: Add handle_new_user trigger (OPTIONAL/BACKUP)
-- ============================================================================
-- Purpose: Auto-create profile entries when users sign up via Supabase Auth
-- Status: OPTIONAL - APIs now handle profile creation directly (see migrations 015+)
-- Reason: This trigger provides a backup safety net, but is not required since:
--   - /api/create-wedding checks and creates profiles if missing
--   - /api/accept-invite checks and creates profiles if missing
-- ============================================================================

-- ============================================================================
-- STEP 1: Create profile auto-creation function
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
  ON CONFLICT (id) DO NOTHING;  -- Don't fail if profile already exists
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 2: Create trigger on auth.users INSERT
-- ============================================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- NOTES FOR DEVELOPERS
-- ============================================================================
-- This trigger is now OPTIONAL because:
-- 1. All API endpoints that need profiles now check and create them
-- 2. This provides defense-in-depth if trigger deployment is skipped
-- 3. The ON CONFLICT clause prevents errors if both paths create profiles
--
-- You can safely skip this migration if your deployment pipeline doesn't
-- support triggers, as the application will still function correctly.
-- ============================================================================

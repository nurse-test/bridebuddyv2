-- ============================================================================
-- BRIDE BUDDY - CREATE MISSING TABLES
-- ============================================================================
-- These tables are referenced in the code but don't exist yet
-- Run this BEFORE applying RLS policies
-- ============================================================================

-- ============================================================================
-- TABLE 1: profiles
-- ============================================================================
-- User profile data (linked to auth.users)
-- This should match the auth.users id

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS profiles_id_idx ON profiles(id);

-- ============================================================================
-- TABLE 2: chat_messages
-- ============================================================================
-- Stores AI chat conversation history

CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  message_type TEXT NOT NULL CHECK (message_type IN ('main', 'bestie')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS chat_messages_wedding_id_idx ON chat_messages(wedding_id);
CREATE INDEX IF NOT EXISTS chat_messages_user_id_idx ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS chat_messages_created_at_idx ON chat_messages(created_at DESC);

-- ============================================================================
-- TABLE 3: pending_updates
-- ============================================================================
-- Wedding profile updates awaiting owner approval

CREATE TABLE IF NOT EXISTS pending_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS pending_updates_wedding_id_idx ON pending_updates(wedding_id);
CREATE INDEX IF NOT EXISTS pending_updates_status_idx ON pending_updates(status);
CREATE INDEX IF NOT EXISTS pending_updates_created_at_idx ON pending_updates(created_at DESC);

-- ============================================================================
-- TABLE 4: invite_codes
-- ============================================================================
-- Wedding invitation codes for sharing with co-planners

CREATE TABLE IF NOT EXISTS invite_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_used BOOLEAN DEFAULT FALSE,
  used_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  used_at TIMESTAMPTZ
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS invite_codes_wedding_id_idx ON invite_codes(wedding_id);
CREATE INDEX IF NOT EXISTS invite_codes_code_idx ON invite_codes(code);
CREATE INDEX IF NOT EXISTS invite_codes_is_used_idx ON invite_codes(is_used);

-- ============================================================================
-- TRIGGER: Auto-create profile on user signup
-- ============================================================================
-- Automatically create a profile entry when a new user signs up

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger to run after user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- TRIGGER: Update updated_at timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to profiles
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Apply to pending_updates
DROP TRIGGER IF EXISTS update_pending_updates_updated_at ON pending_updates;
CREATE TRIGGER update_pending_updates_updated_at
  BEFORE UPDATE ON pending_updates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check all 4 tables were created
SELECT
  tablename,
  CASE
    WHEN tablename IN (
      SELECT tablename FROM pg_tables
      WHERE schemaname = 'public'
    ) THEN '✓ EXISTS'
    ELSE '✗ MISSING'
  END as status
FROM (
  VALUES
    ('profiles'),
    ('chat_messages'),
    ('pending_updates'),
    ('invite_codes')
) AS t(tablename);

-- Check all tables together
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'wedding_profiles',
    'wedding_members',
    'profiles',
    'chat_messages',
    'pending_updates',
    'invite_codes'
  )
ORDER BY tablename;
-- Should return all 6 tables

-- ============================================================================
-- COMPLETE
-- ============================================================================
-- All tables created successfully!
-- Next step: Run rls_remaining_tables.sql to secure these new tables
-- ============================================================================

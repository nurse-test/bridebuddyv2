-- ============================================================================
-- BRIDE BUDDY - MASTER DATABASE INITIALIZATION SCRIPT
-- ============================================================================
-- This is the MASTER script for deploying the complete Bride Buddy database
-- from scratch. It executes all migrations in the correct order.
--
-- USAGE:
--   1. Copy this entire file
--   2. Paste into Supabase SQL Editor
--   3. Execute once
--   4. Run database_status_check.sql to verify deployment
--
-- SAFE TO RE-RUN: All statements use IF NOT EXISTS or DROP IF EXISTS
-- ============================================================================

-- ============================================================================
-- DEPLOYMENT SUMMARY
-- ============================================================================
/*
This script will create:
  - 6 core tables (wedding_profiles, wedding_members, profiles, chat_messages, pending_updates, invite_codes)
  - 3 bestie tables (bestie_permissions, bestie_knowledge, bestie_profile)
  - 30+ RLS policies to secure all data
  - Triggers for auto-updating timestamps
  - Helper functions and views
  - Full bestie permission system

Estimated execution time: 5-10 seconds
*/

-- ============================================================================
-- STEP 1: CREATE ALL BASE TABLES
-- ============================================================================
-- Creates: wedding_profiles, wedding_members, profiles, chat_messages,
--          pending_updates, invite_codes
-- Source: create_missing_tables.sql
-- ============================================================================

-- TABLE 1: profiles
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  is_owner BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS profiles_id_idx ON profiles(id);
CREATE INDEX IF NOT EXISTS profiles_is_owner_idx ON profiles(is_owner);

-- TABLE 2: wedding_profiles
CREATE TABLE IF NOT EXISTS wedding_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS wedding_profiles_owner_id_idx ON wedding_profiles(owner_id);
CREATE INDEX IF NOT EXISTS wedding_profiles_created_at_idx ON wedding_profiles(created_at DESC);

-- TABLE 3: wedding_members
CREATE TABLE IF NOT EXISTS wedding_members (
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  PRIMARY KEY (wedding_id, user_id)
);

CREATE INDEX IF NOT EXISTS wedding_members_user_id_idx ON wedding_members(user_id);
CREATE INDEX IF NOT EXISTS wedding_members_wedding_id_idx ON wedding_members(wedding_id);
CREATE INDEX IF NOT EXISTS wedding_members_role_idx ON wedding_members(role);

-- Add role constraint: Only 'owner', 'partner', 'bestie' allowed
ALTER TABLE wedding_members DROP CONSTRAINT IF EXISTS wedding_members_role_check;
ALTER TABLE wedding_members
  ADD CONSTRAINT wedding_members_role_check
  CHECK (role IN ('owner', 'partner', 'bestie'));

-- TABLE 5: chat_messages
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  message_type TEXT NOT NULL CHECK (message_type IN ('main', 'bestie')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS chat_messages_wedding_id_idx ON chat_messages(wedding_id);
CREATE INDEX IF NOT EXISTS chat_messages_user_id_idx ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS chat_messages_created_at_idx ON chat_messages(created_at DESC);

-- TABLE 6: pending_updates
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

CREATE INDEX IF NOT EXISTS pending_updates_wedding_id_idx ON pending_updates(wedding_id);
CREATE INDEX IF NOT EXISTS pending_updates_status_idx ON pending_updates(status);
CREATE INDEX IF NOT EXISTS pending_updates_created_at_idx ON pending_updates(created_at DESC);

-- TABLE 7: invite_codes
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

CREATE INDEX IF NOT EXISTS invite_codes_wedding_id_idx ON invite_codes(wedding_id);
CREATE INDEX IF NOT EXISTS invite_codes_code_idx ON invite_codes(code);
CREATE INDEX IF NOT EXISTS invite_codes_is_used_idx ON invite_codes(is_used);

-- TRIGGER: Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, is_owner)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    false  -- Default: not a wedding owner yet
  )
  ON CONFLICT (id) DO NOTHING;  -- Prevents errors if profile already exists
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- TRIGGER: Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_pending_updates_updated_at ON pending_updates;
CREATE TRIGGER update_pending_updates_updated_at
  BEFORE UPDATE ON pending_updates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STEP 2: APPLY RLS POLICIES TO CRITICAL TABLES
-- ============================================================================
-- Secures: wedding_profiles, wedding_members
-- Source: rls_critical_tables_fixed.sql
-- ============================================================================

-- TABLE: wedding_profiles
ALTER TABLE wedding_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their weddings" ON wedding_profiles;
DROP POLICY IF EXISTS "Users can create wedding as owner" ON wedding_profiles;
DROP POLICY IF EXISTS "Owners can update their wedding" ON wedding_profiles;
DROP POLICY IF EXISTS "Backend full access" ON wedding_profiles;

CREATE POLICY "Users can view their weddings"
ON wedding_profiles FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Users can create wedding as owner"
ON wedding_profiles FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Owners can update their wedding"
ON wedding_profiles FOR UPDATE
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Backend full access"
ON wedding_profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- FUNCTION: Helper to check wedding membership (prevents RLS recursion)
CREATE OR REPLACE FUNCTION is_wedding_member(p_wedding_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM wedding_members
    WHERE wedding_id = p_wedding_id
      AND user_id = p_user_id
  );
$$;

-- FUNCTION: Helper to check if user is wedding owner (prevents RLS recursion)
CREATE OR REPLACE FUNCTION is_wedding_owner(p_wedding_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM wedding_members
    WHERE wedding_id = p_wedding_id
      AND user_id = p_user_id
      AND role = 'owner'
  );
$$;

-- TABLE: wedding_members
ALTER TABLE wedding_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view members of their wedding" ON wedding_members;
DROP POLICY IF EXISTS "Users can view wedding members" ON wedding_members;
DROP POLICY IF EXISTS "Users can join as owner" ON wedding_members;
DROP POLICY IF EXISTS "Users can join as member" ON wedding_members;
DROP POLICY IF EXISTS "Owners can manage members" ON wedding_members;
DROP POLICY IF EXISTS "Backend full access" ON wedding_members;

CREATE POLICY "Users can view wedding members"
ON wedding_members FOR SELECT
TO authenticated
USING (
  -- Users can see members of weddings they're part of
  -- Uses security definer function to prevent recursion
  is_wedding_member(wedding_id, auth.uid())
);

CREATE POLICY "Users can join as owner"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND role = 'owner'
);

CREATE POLICY "Users can join as member"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND role != 'owner'
);

CREATE POLICY "Owners can manage members"
ON wedding_members FOR UPDATE
TO authenticated
USING (
  -- Only owners can update members
  -- Uses security definer function to prevent recursion
  is_wedding_owner(wedding_id, auth.uid())
)
WITH CHECK (
  -- Ensure updated rows still belong to weddings the user owns
  is_wedding_owner(wedding_id, auth.uid())
);

CREATE POLICY "Backend full access"
ON wedding_members FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 3: APPLY RLS POLICIES TO REMAINING TABLES
-- ============================================================================
-- Secures: chat_messages, pending_updates, invite_codes, profiles
-- Source: rls_remaining_tables.sql
-- ============================================================================

-- TABLE: chat_messages
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own chat messages" ON chat_messages;
DROP POLICY IF EXISTS "Backend can insert messages" ON chat_messages;
DROP POLICY IF EXISTS "Backend full access" ON chat_messages;

CREATE POLICY "Users can view own chat messages"
ON chat_messages FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  AND wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Backend can insert messages"
ON chat_messages FOR INSERT
TO service_role
WITH CHECK (true);

CREATE POLICY "Backend full access"
ON chat_messages FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- TABLE: pending_updates
ALTER TABLE pending_updates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view wedding updates" ON pending_updates;
DROP POLICY IF EXISTS "Owners can approve/reject updates" ON pending_updates;
DROP POLICY IF EXISTS "Backend can create updates" ON pending_updates;
DROP POLICY IF EXISTS "Backend full access" ON pending_updates;

CREATE POLICY "Users can view wedding updates"
ON pending_updates FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Owners can approve/reject updates"
ON pending_updates FOR UPDATE
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role = 'owner'
  )
)
WITH CHECK (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role = 'owner'
  )
);

CREATE POLICY "Backend can create updates"
ON pending_updates FOR INSERT
TO service_role
WITH CHECK (true);

CREATE POLICY "Backend full access"
ON pending_updates FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- TABLE: invite_codes
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view wedding invites" ON invite_codes;
DROP POLICY IF EXISTS "Members can create invites" ON invite_codes;
DROP POLICY IF EXISTS "Backend full access" ON invite_codes;

CREATE POLICY "Users can view wedding invites"
ON invite_codes FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Members can create invites"
ON invite_codes FOR INSERT
TO authenticated
WITH CHECK (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Backend full access"
ON invite_codes FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- TABLE: profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view co-member profiles" ON profiles;
DROP POLICY IF EXISTS "Users can create own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Backend full access" ON profiles;

CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
TO authenticated
USING (id = auth.uid());

CREATE POLICY "Users can view co-member profiles"
ON profiles FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT DISTINCT user_id
    FROM wedding_members
    WHERE wedding_id IN (
      SELECT wedding_id
      FROM wedding_members
      WHERE user_id = auth.uid()
    )
  )
);

CREATE POLICY "Users can create own profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

CREATE POLICY "Backend full access"
ON profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 4: ADD BESTIE SYSTEM - SCHEMA CHANGES
-- ============================================================================
-- Adds invited_by_user_id and wedding_profile_permissions to wedding_members
-- Source: migrations/001_add_invited_by_to_wedding_members.sql
-- ============================================================================

ALTER TABLE wedding_members
ADD COLUMN IF NOT EXISTS invited_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE wedding_members
ADD COLUMN IF NOT EXISTS wedding_profile_permissions JSONB
DEFAULT '{"can_read": false, "can_edit": false}'::jsonb;

ALTER TABLE wedding_members
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS wedding_members_invited_by_idx
ON wedding_members(invited_by_user_id);

CREATE INDEX IF NOT EXISTS wedding_members_created_at_idx
ON wedding_members(created_at DESC);

-- Migrate existing data
UPDATE wedding_members
SET invited_by_user_id = user_id
WHERE role = 'owner'
  AND invited_by_user_id IS NULL;

UPDATE wedding_members wm
SET invited_by_user_id = ic.created_by
FROM invite_codes ic
WHERE ic.used_by = wm.user_id
  AND ic.wedding_id = wm.wedding_id
  AND wm.role IN ('member', 'bestie')
  AND wm.invited_by_user_id IS NULL;

UPDATE wedding_members wm
SET invited_by_user_id = wp.owner_id
FROM wedding_profiles wp
WHERE wm.wedding_id = wp.id
  AND wm.invited_by_user_id IS NULL;

-- Add constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'wedding_profile_permissions_valid_json'
  ) THEN
    ALTER TABLE wedding_members
    ADD CONSTRAINT wedding_profile_permissions_valid_json
    CHECK (
      jsonb_typeof(wedding_profile_permissions) = 'object'
      AND wedding_profile_permissions ? 'can_read'
      AND wedding_profile_permissions ? 'can_edit'
    );
  END IF;
END $$;

-- ============================================================================
-- STEP 5: CREATE BESTIE_PERMISSIONS TABLE
-- ============================================================================
-- Source: migrations/002_create_bestie_permissions_table.sql
-- ============================================================================

CREATE TABLE IF NOT EXISTS bestie_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  inviter_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  permissions JSONB NOT NULL DEFAULT '{"can_read": false, "can_edit": false}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_bestie_permissions_per_wedding UNIQUE (bestie_user_id, wedding_id),
  CONSTRAINT bestie_not_inviter CHECK (bestie_user_id != inviter_user_id)
);

CREATE INDEX IF NOT EXISTS bestie_permissions_bestie_idx ON bestie_permissions(bestie_user_id);
CREATE INDEX IF NOT EXISTS bestie_permissions_inviter_idx ON bestie_permissions(inviter_user_id);
CREATE INDEX IF NOT EXISTS bestie_permissions_wedding_idx ON bestie_permissions(wedding_id);
CREATE INDEX IF NOT EXISTS bestie_permissions_bestie_wedding_idx ON bestie_permissions(bestie_user_id, wedding_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'permissions_valid_json'
  ) THEN
    ALTER TABLE bestie_permissions
    ADD CONSTRAINT permissions_valid_json
    CHECK (
      jsonb_typeof(permissions) = 'object'
      AND permissions ? 'can_read'
      AND permissions ? 'can_edit'
      AND (permissions->>'can_read')::text IN ('true', 'false')
      AND (permissions->>'can_edit')::text IN ('true', 'false')
    );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION update_bestie_permissions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_bestie_permissions_updated_at ON bestie_permissions;

CREATE TRIGGER trigger_update_bestie_permissions_updated_at
  BEFORE UPDATE ON bestie_permissions
  FOR EACH ROW
  EXECUTE FUNCTION update_bestie_permissions_updated_at();

-- ============================================================================
-- STEP 6: CREATE BESTIE_KNOWLEDGE TABLE
-- ============================================================================
-- Source: migrations/003_create_bestie_knowledge_table.sql
-- ============================================================================

CREATE TABLE IF NOT EXISTS bestie_knowledge (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  knowledge_type TEXT NOT NULL DEFAULT 'note'
    CHECK (knowledge_type IN ('note', 'vendor', 'task', 'expense', 'idea', 'checklist', 'contact')),
  is_private BOOLEAN DEFAULT FALSE,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS bestie_knowledge_bestie_idx ON bestie_knowledge(bestie_user_id);
CREATE INDEX IF NOT EXISTS bestie_knowledge_wedding_idx ON bestie_knowledge(wedding_id);
CREATE INDEX IF NOT EXISTS bestie_knowledge_type_idx ON bestie_knowledge(knowledge_type);
CREATE INDEX IF NOT EXISTS bestie_knowledge_private_idx ON bestie_knowledge(is_private);
CREATE INDEX IF NOT EXISTS bestie_knowledge_bestie_wedding_idx ON bestie_knowledge(bestie_user_id, wedding_id);
CREATE INDEX IF NOT EXISTS bestie_knowledge_created_at_idx ON bestie_knowledge(created_at DESC);
CREATE INDEX IF NOT EXISTS bestie_knowledge_content_search_idx ON bestie_knowledge USING GIN (to_tsvector('english', content));

CREATE OR REPLACE FUNCTION update_bestie_knowledge_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_bestie_knowledge_updated_at ON bestie_knowledge;

CREATE TRIGGER trigger_update_bestie_knowledge_updated_at
  BEFORE UPDATE ON bestie_knowledge
  FOR EACH ROW
  EXECUTE FUNCTION update_bestie_knowledge_updated_at();

-- ============================================================================
-- STEP 6A: CREATE BESTIE_PROFILE TABLE
-- ============================================================================
-- Source: migrations/015_create_bestie_profile_table.sql
-- LAUNCH BLOCKER FIX: This table was referenced but never created
-- ============================================================================

CREATE TABLE IF NOT EXISTS bestie_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,
  bestie_brief TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_bestie_profile_per_wedding UNIQUE (bestie_user_id, wedding_id)
);

CREATE INDEX IF NOT EXISTS idx_bestie_profile_bestie_user ON bestie_profile(bestie_user_id);
CREATE INDEX IF NOT EXISTS idx_bestie_profile_wedding ON bestie_profile(wedding_id);
CREATE INDEX IF NOT EXISTS idx_bestie_profile_bestie_wedding ON bestie_profile(bestie_user_id, wedding_id);

ALTER TABLE bestie_profile ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Bestie can view own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Bestie can create own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Bestie can update own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Bestie can delete own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Wedding members can view bestie profiles" ON bestie_profile;
DROP POLICY IF EXISTS "Backend full access" ON bestie_profile;

CREATE POLICY "Bestie can view own profile"
  ON bestie_profile FOR SELECT
  TO authenticated
  USING (bestie_user_id = auth.uid());

CREATE POLICY "Bestie can create own profile"
  ON bestie_profile FOR INSERT
  TO authenticated
  WITH CHECK (bestie_user_id = auth.uid());

CREATE POLICY "Bestie can update own profile"
  ON bestie_profile FOR UPDATE
  TO authenticated
  USING (bestie_user_id = auth.uid())
  WITH CHECK (bestie_user_id = auth.uid());

CREATE POLICY "Bestie can delete own profile"
  ON bestie_profile FOR DELETE
  TO authenticated
  USING (bestie_user_id = auth.uid());

CREATE POLICY "Wedding members can view bestie profiles"
  ON bestie_profile FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = bestie_profile.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Backend full access"
  ON bestie_profile FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION update_bestie_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_bestie_profile_updated_at ON bestie_profile;

CREATE TRIGGER trigger_update_bestie_profile_updated_at
  BEFORE UPDATE ON bestie_profile
  FOR EACH ROW
  EXECUTE FUNCTION update_bestie_profile_updated_at();

-- ============================================================================
-- STEP 7: RLS POLICIES FOR BESTIE_PERMISSIONS
-- ============================================================================
-- Source: migrations/004_rls_bestie_permissions.sql
-- ============================================================================

ALTER TABLE bestie_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Bestie can view own permissions" ON bestie_permissions;
DROP POLICY IF EXISTS "Bestie can update own permissions" ON bestie_permissions;
DROP POLICY IF EXISTS "Inviter can view bestie permissions" ON bestie_permissions;
DROP POLICY IF EXISTS "Backend full access" ON bestie_permissions;

CREATE POLICY "Bestie can view own permissions"
ON bestie_permissions FOR SELECT
TO authenticated
USING (bestie_user_id = auth.uid());

CREATE POLICY "Bestie can update own permissions"
ON bestie_permissions FOR UPDATE
TO authenticated
USING (bestie_user_id = auth.uid())
WITH CHECK (
  bestie_user_id = auth.uid()
  AND bestie_user_id = (SELECT bestie_user_id FROM bestie_permissions WHERE id = bestie_permissions.id)
  AND inviter_user_id = (SELECT inviter_user_id FROM bestie_permissions WHERE id = bestie_permissions.id)
);

CREATE POLICY "Inviter can view bestie permissions"
ON bestie_permissions FOR SELECT
TO authenticated
USING (inviter_user_id = auth.uid());

CREATE POLICY "Backend full access"
ON bestie_permissions FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 8: RLS POLICIES FOR BESTIE_KNOWLEDGE
-- ============================================================================
-- Source: migrations/005_rls_bestie_knowledge.sql
-- ============================================================================

ALTER TABLE bestie_knowledge ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Bestie can view own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can create own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can update own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can delete own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Inviter can view if granted access" ON bestie_knowledge;
DROP POLICY IF EXISTS "Inviter can edit if granted access" ON bestie_knowledge;
DROP POLICY IF EXISTS "Backend full access" ON bestie_knowledge;

CREATE POLICY "Bestie can view own knowledge"
ON bestie_knowledge FOR SELECT
TO authenticated
USING (bestie_user_id = auth.uid());

CREATE POLICY "Bestie can create own knowledge"
ON bestie_knowledge FOR INSERT
TO authenticated
WITH CHECK (bestie_user_id = auth.uid());

CREATE POLICY "Bestie can update own knowledge"
ON bestie_knowledge FOR UPDATE
TO authenticated
USING (bestie_user_id = auth.uid())
WITH CHECK (bestie_user_id = auth.uid());

CREATE POLICY "Bestie can delete own knowledge"
ON bestie_knowledge FOR DELETE
TO authenticated
USING (bestie_user_id = auth.uid());

CREATE POLICY "Inviter can view if granted access"
ON bestie_knowledge FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM bestie_permissions bp
    WHERE bp.bestie_user_id = bestie_knowledge.bestie_user_id
      AND bp.inviter_user_id = auth.uid()
      AND bp.wedding_id = bestie_knowledge.wedding_id
      AND (bp.permissions->>'can_read')::boolean = true
  )
  AND is_private = false
);

CREATE POLICY "Inviter can edit if granted access"
ON bestie_knowledge FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM bestie_permissions bp
    WHERE bp.bestie_user_id = bestie_knowledge.bestie_user_id
      AND bp.inviter_user_id = auth.uid()
      AND bp.wedding_id = bestie_knowledge.wedding_id
      AND (bp.permissions->>'can_edit')::boolean = true
  )
  AND is_private = false
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM bestie_permissions bp
    WHERE bp.bestie_user_id = bestie_knowledge.bestie_user_id
      AND bp.inviter_user_id = auth.uid()
      AND bp.wedding_id = bestie_knowledge.wedding_id
      AND (bp.permissions->>'can_edit')::boolean = true
  )
  AND bestie_user_id = (SELECT bestie_user_id FROM bestie_knowledge WHERE id = bestie_knowledge.id)
  AND is_private = false
);

CREATE POLICY "Backend full access"
ON bestie_knowledge FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 9: UNIFIED INVITE SYSTEM
-- ============================================================================
-- Source: migrations/006_unified_invite_system.sql (partial - core changes only)
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invite_codes' AND column_name = 'role'
  ) THEN
    ALTER TABLE invite_codes ADD COLUMN role TEXT;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invite_codes' AND column_name = 'invite_token'
  ) THEN
    ALTER TABLE invite_codes ADD COLUMN invite_token TEXT UNIQUE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invite_codes' AND column_name = 'wedding_profile_permissions'
  ) THEN
    ALTER TABLE invite_codes
      ADD COLUMN wedding_profile_permissions JSONB DEFAULT '{"read": false, "edit": false}'::jsonb;
  END IF;
END $$;

UPDATE invite_codes
SET invite_token = code
WHERE invite_token IS NULL AND code IS NOT NULL;

-- Add role constraint: Only 'partner' and 'bestie' can be invited
-- (owner is created during wedding creation, not via invite)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'invite_codes_role_check'
  ) THEN
    ALTER TABLE invite_codes
      ADD CONSTRAINT invite_codes_role_check
      CHECK (role IN ('partner', 'bestie'));
  END IF;
END $$;

-- ============================================================================
-- STEP 9.5: FIX INVITE FUNCTIONS (SCHEMA MISMATCH)
-- ============================================================================
-- Source: migrations/020_fix_invite_functions_schema.sql
-- Fix database functions to use is_used instead of used
-- Remove expires_at references (one-time use only)
-- ============================================================================

-- Drop and recreate is_invite_valid function with correct column names
DROP FUNCTION IF EXISTS is_invite_valid(TEXT);

CREATE OR REPLACE FUNCTION is_invite_valid(token TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM invite_codes
    WHERE invite_token = token
      AND (is_used = false OR is_used IS NULL)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate get_invite_details function with correct column names
DROP FUNCTION IF EXISTS get_invite_details(TEXT);

CREATE OR REPLACE FUNCTION get_invite_details(token TEXT)
RETURNS TABLE (
  wedding_id UUID,
  role TEXT,
  is_valid BOOLEAN,
  is_used BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ic.wedding_id,
    ic.role,
    (ic.is_used = false OR ic.is_used IS NULL) AS is_valid,
    COALESCE(ic.is_used, false) AS is_used
  FROM invite_codes ic
  WHERE ic.invite_token = token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_invite_details(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION is_invite_valid(TEXT) TO anon, authenticated;

-- ============================================================================
-- STEP 10: ADD MISSING WEDDING_PROFILES COLUMNS
-- ============================================================================
-- Source: migrations/007_add_missing_wedding_profile_columns.sql
-- Adds all subscription, wedding data, and vendor columns
-- ============================================================================

-- Add basic wedding information columns
DO $$
BEGIN
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

-- Add vendor information columns
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

-- Add subscription and business columns
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

-- Create trigger for updated_at
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
-- STEP 11: ADD ENGAGEMENT DATE AND ONBOARDING DATA
-- ============================================================================
-- Source: migrations/008_add_engagement_and_onboarding_data.sql
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
-- STEP 11: CREATE ACTIVE INVITES VIEW
-- ============================================================================
-- Must be created AFTER wedding_profiles columns are added (partner1_name, partner2_name)
-- SECURITY: View uses SECURITY INVOKER (default) - respects RLS policies
-- ============================================================================

DROP VIEW IF EXISTS active_invites;

-- Create view WITHOUT security definer (uses SECURITY INVOKER by default)
-- This view respects RLS policies and runs with the privileges of the calling user
CREATE VIEW active_invites
WITH (security_invoker = true)
AS
SELECT
  ic.id,
  ic.wedding_id,
  ic.invite_token,
  ic.role,
  ic.wedding_profile_permissions,
  ic.created_by,
  ic.created_at,
  ic.is_used,
  ic.used_by,
  ic.used_at,
  wp.partner1_name,
  wp.partner2_name
FROM invite_codes ic
JOIN wedding_profiles wp ON ic.wedding_id = wp.id
WHERE (ic.is_used = false OR ic.is_used IS NULL);

-- Grant SELECT to authenticated users (they'll see invites via RLS policies)
GRANT SELECT ON active_invites TO authenticated;

-- Comment explaining security model
COMMENT ON VIEW active_invites IS 'Shows active (unused) invite codes. Uses SECURITY INVOKER to respect RLS policies - users only see invites for weddings they are members of.';

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================

SELECT
  '✓✓✓ DATABASE INITIALIZATION COMPLETE' as status,
  'Run database_status_check.sql to verify' as next_step;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Run this query to verify deployment:
-- SELECT tablename, rowsecurity FROM pg_tables
-- WHERE schemaname = 'public' AND tablename IN (
--   'wedding_profiles', 'wedding_members', 'profiles', 'chat_messages',
--   'pending_updates', 'invite_codes', 'bestie_permissions', 'bestie_knowledge'
-- );
-- Expected: All 8 tables with rowsecurity = true
-- ============================================================================

-- ============================================================================
-- MIGRATION 022: Fixed Role-Based Permissions (Remove Manual Permissions)
-- ============================================================================
-- Purpose: Replace manual permission toggles with fixed role-based access
--
-- FIXED PERMISSIONS:
-- Owner/Partner: Full VIEW+EDIT on wedding data, ZERO access to bestie data
-- Bestie: VIEW ONLY on wedding_profiles, Full VIEW+EDIT on bestie data
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Deprecate bestie_permissions table
-- ============================================================================
-- We're keeping the table for historical data but no longer using it
-- The 'permissions' column is now ignored - role determines access

COMMENT ON TABLE bestie_permissions IS 'DEPRECATED: Permissions are now fixed by role. This table is kept for historical data only.';
COMMENT ON COLUMN bestie_permissions.permissions IS 'DEPRECATED: No longer used. Permissions are determined by role in wedding_members table.';

-- ============================================================================
-- STEP 2: Update wedding_profiles RLS policies
-- ============================================================================
-- Owner/Partner: Full VIEW + EDIT
-- Bestie: VIEW ONLY (can read for planning context)

ALTER TABLE wedding_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their weddings" ON wedding_profiles;
DROP POLICY IF EXISTS "Users can create wedding as owner" ON wedding_profiles;
DROP POLICY IF EXISTS "Wedding owners can update wedding" ON wedding_profiles;
DROP POLICY IF EXISTS "Owners can update their wedding" ON wedding_profiles;
DROP POLICY IF EXISTS "Backend full access" ON wedding_profiles;

-- SELECT: All wedding members (owner, partner, bestie) can view
CREATE POLICY "Wedding members can view wedding profile"
ON wedding_profiles FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
);

-- INSERT: Only owners can create weddings
CREATE POLICY "Owners can create wedding"
ON wedding_profiles FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

-- UPDATE: Only owner and partner can edit
CREATE POLICY "Owners and partners can update wedding"
ON wedding_profiles FOR UPDATE
TO authenticated
USING (
  id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role IN ('owner', 'partner')
  )
)
WITH CHECK (
  id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role IN ('owner', 'partner')
  )
);

-- DELETE: Only owner can delete
CREATE POLICY "Owners can delete wedding"
ON wedding_profiles FOR DELETE
TO authenticated
USING (owner_id = auth.uid());

CREATE POLICY "Backend full access"
ON wedding_profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 3: Update bestie_knowledge RLS policies
-- ============================================================================
-- Owner/Partner: ZERO ACCESS (can't see, edit, or know it exists)
-- Bestie: Full VIEW + EDIT (only their own knowledge)

ALTER TABLE bestie_knowledge ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Bestie can view own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can create own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can update own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Bestie can delete own knowledge" ON bestie_knowledge;
DROP POLICY IF EXISTS "Inviter can view if granted access" ON bestie_knowledge;
DROP POLICY IF EXISTS "Inviter can edit if granted access" ON bestie_knowledge;
DROP POLICY IF EXISTS "Backend full access" ON bestie_knowledge;

-- SELECT: Only bestie can view their own knowledge
CREATE POLICY "Besties can view own knowledge"
ON bestie_knowledge FOR SELECT
TO authenticated
USING (
  bestie_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_knowledge.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'
  )
);

-- INSERT: Only bestie can create their own knowledge
CREATE POLICY "Besties can create own knowledge"
ON bestie_knowledge FOR INSERT
TO authenticated
WITH CHECK (
  bestie_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_knowledge.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'
  )
);

-- UPDATE: Only bestie can update their own knowledge
CREATE POLICY "Besties can update own knowledge"
ON bestie_knowledge FOR UPDATE
TO authenticated
USING (
  bestie_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_knowledge.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'
  )
)
WITH CHECK (
  bestie_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_knowledge.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'
  )
);

-- DELETE: Only bestie can delete their own knowledge
CREATE POLICY "Besties can delete own knowledge"
ON bestie_knowledge FOR DELETE
TO authenticated
USING (
  bestie_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_knowledge.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'
  )
);

CREATE POLICY "Backend full access"
ON bestie_knowledge FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 4: Update bestie_profile RLS policies
-- ============================================================================
-- Owner/Partner: ZERO ACCESS
-- Bestie: Full VIEW + EDIT (only their own profile)

ALTER TABLE bestie_profile ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Bestie can view own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Bestie can create own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Bestie can update own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Bestie can delete own profile" ON bestie_profile;
DROP POLICY IF EXISTS "Wedding members can view bestie profiles" ON bestie_profile;
DROP POLICY IF EXISTS "Backend full access" ON bestie_profile;

-- SELECT: Only bestie can view their own profile
CREATE POLICY "Besties can view own profile"
ON bestie_profile FOR SELECT
TO authenticated
USING (
  bestie_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_profile.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'
  )
);

-- INSERT: Only bestie can create their own profile
CREATE POLICY "Besties can create own profile"
ON bestie_profile FOR INSERT
TO authenticated
WITH CHECK (
  bestie_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_profile.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'
  )
);

-- UPDATE: Only bestie can update their own profile
CREATE POLICY "Besties can update own profile"
ON bestie_profile FOR UPDATE
TO authenticated
USING (
  bestie_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_profile.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'
  )
)
WITH CHECK (
  bestie_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_profile.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'
  )
);

-- DELETE: Only bestie can delete their own profile
CREATE POLICY "Besties can delete own profile"
ON bestie_profile FOR DELETE
TO authenticated
USING (
  bestie_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = bestie_profile.wedding_id
      AND wedding_members.user_id = auth.uid()
      AND wedding_members.role = 'bestie'
  )
);

CREATE POLICY "Backend full access"
ON bestie_profile FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 5: Update chat_messages RLS policies
-- ============================================================================
-- Owner/Partner: Can view/create main chat messages
-- Bestie: Can view/create bestie chat messages (message_type = 'bestie')
-- STRICT SEPARATION: Owners cannot see bestie chats, besties cannot see main chats

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own chat messages" ON chat_messages;
DROP POLICY IF EXISTS "Backend can insert messages" ON chat_messages;
DROP POLICY IF EXISTS "Backend full access" ON chat_messages;

-- SELECT: Users can view their own messages of the appropriate type
CREATE POLICY "Users can view own chat messages by type"
ON chat_messages FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  AND wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
  AND (
    -- Owner/Partner can only see main chat
    (message_type = 'main' AND EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = chat_messages.wedding_id
        AND wedding_members.user_id = auth.uid()
        AND wedding_members.role IN ('owner', 'partner')
    ))
    OR
    -- Bestie can only see bestie chat
    (message_type = 'bestie' AND EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = chat_messages.wedding_id
        AND wedding_members.user_id = auth.uid()
        AND wedding_members.role = 'bestie'
    ))
  )
);

-- INSERT: Backend can insert messages (API handles validation)
CREATE POLICY "Backend can insert messages"
ON chat_messages FOR INSERT
TO service_role
WITH CHECK (true);

CREATE POLICY "Backend full access"
ON chat_messages FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 6: Update invite_codes RLS policies
-- ============================================================================
-- Owner/Partner: Can create and view invites
-- Bestie: ZERO ACCESS

ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view wedding invites" ON invite_codes;
DROP POLICY IF EXISTS "Wedding members can view invites" ON invite_codes;
DROP POLICY IF EXISTS "Members can create invites" ON invite_codes;
DROP POLICY IF EXISTS "Owners and partners can create invites" ON invite_codes;
DROP POLICY IF EXISTS "Wedding owners can create invites" ON invite_codes;
DROP POLICY IF EXISTS "Backend full access" ON invite_codes;

-- SELECT: Only owner and partner can view invites
CREATE POLICY "Owners and partners can view invites"
ON invite_codes FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role IN ('owner', 'partner')
  )
);

-- INSERT: Only owner and partner can create invites
CREATE POLICY "Owners and partners can create invites"
ON invite_codes FOR INSERT
TO authenticated
WITH CHECK (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role IN ('owner', 'partner')
  )
  AND created_by = auth.uid()
);

CREATE POLICY "Backend full access"
ON invite_codes FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 7: Update pending_updates RLS policies
-- ============================================================================
-- Owner/Partner: Can view and approve/reject updates
-- Bestie: ZERO ACCESS

ALTER TABLE pending_updates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view wedding updates" ON pending_updates;
DROP POLICY IF EXISTS "Owners can approve/reject updates" ON pending_updates;
DROP POLICY IF EXISTS "Owners and partners can approve/reject updates" ON pending_updates;
DROP POLICY IF EXISTS "Backend can create updates" ON pending_updates;
DROP POLICY IF EXISTS "Backend full access" ON pending_updates;

-- SELECT: Only owner and partner can view updates
CREATE POLICY "Owners and partners can view updates"
ON pending_updates FOR SELECT
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role IN ('owner', 'partner')
  )
);

-- UPDATE: Only owner and partner can approve/reject
CREATE POLICY "Owners and partners can manage updates"
ON pending_updates FOR UPDATE
TO authenticated
USING (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role IN ('owner', 'partner')
  )
)
WITH CHECK (
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
      AND role IN ('owner', 'partner')
  )
);

-- INSERT: Backend can create updates
CREATE POLICY "Backend can create updates"
ON pending_updates FOR INSERT
TO service_role
WITH CHECK (true);

CREATE POLICY "Backend full access"
ON pending_updates FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 8: Update wedding_members RLS policies
-- ============================================================================
-- All members can view other members, only owner/partner can manage

ALTER TABLE wedding_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view members of their wedding" ON wedding_members;
DROP POLICY IF EXISTS "Users can view wedding members" ON wedding_members;
DROP POLICY IF EXISTS "Users can join as owner" ON wedding_members;
DROP POLICY IF EXISTS "Users can join as member" ON wedding_members;
DROP POLICY IF EXISTS "Owners can manage members" ON wedding_members;
DROP POLICY IF EXISTS "Wedding owners can update members" ON wedding_members;
DROP POLICY IF EXISTS "Owners and partners can update members" ON wedding_members;
DROP POLICY IF EXISTS "Backend full access" ON wedding_members;

-- SELECT: All members can view other members
CREATE POLICY "Wedding members can view members"
ON wedding_members FOR SELECT
TO authenticated
USING (
  is_wedding_member(wedding_id, auth.uid())
);

-- INSERT: Users can join as owner (when creating wedding)
CREATE POLICY "Users can join as owner"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND role = 'owner'
);

-- INSERT: Users can join as partner or bestie (via invite acceptance)
CREATE POLICY "Users can join as partner or bestie"
ON wedding_members FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND role IN ('partner', 'bestie')
);

-- UPDATE: Only owner and partner can manage members
CREATE POLICY "Owners and partners can manage members"
ON wedding_members FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members wm2
    WHERE wm2.wedding_id = wedding_members.wedding_id
      AND wm2.user_id = auth.uid()
      AND wm2.role IN ('owner', 'partner')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM wedding_members wm2
    WHERE wm2.wedding_id = wedding_members.wedding_id
      AND wm2.user_id = auth.uid()
      AND wm2.role IN ('owner', 'partner')
  )
);

CREATE POLICY "Backend full access"
ON wedding_members FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 9: Add comments documenting the fixed permission system
-- ============================================================================

COMMENT ON TABLE wedding_profiles IS 'Wedding planning data. Owner/Partner: Full access. Bestie: View-only (for planning context).';
COMMENT ON TABLE bestie_knowledge IS 'Private bestie planning data. OWNER/PARTNER CANNOT ACCESS. Only visible to the bestie who created it.';
COMMENT ON TABLE bestie_profile IS 'Bestie profile data. OWNER/PARTNER CANNOT ACCESS. Only visible to the bestie.';
COMMENT ON TABLE chat_messages IS 'Chat history. main: Owner/Partner only. bestie: Bestie only. Strictly separated.';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify RLS is enabled on all tables
DO $$
DECLARE
  missing_rls TEXT[];
BEGIN
  SELECT array_agg(tablename)
  INTO missing_rls
  FROM pg_tables
  WHERE schemaname = 'public'
    AND tablename IN (
      'wedding_profiles', 'wedding_members', 'bestie_knowledge',
      'bestie_profile', 'chat_messages', 'invite_codes', 'pending_updates'
    )
    AND rowsecurity = false;

  IF array_length(missing_rls, 1) > 0 THEN
    RAISE WARNING 'RLS not enabled on tables: %', array_to_string(missing_rls, ', ');
  ELSE
    RAISE NOTICE '✓ RLS enabled on all critical tables';
  END IF;
END $$;

-- Count policies per table
SELECT
  schemaname,
  tablename,
  COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'wedding_profiles', 'wedding_members', 'bestie_knowledge',
    'bestie_profile', 'chat_messages', 'invite_codes', 'pending_updates'
  )
GROUP BY schemaname, tablename
ORDER BY tablename;

COMMIT;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

SELECT
  '✓ Migration 022 Complete' as status,
  'Fixed role-based permissions implemented' as message;

-- Summary of changes:
-- ✅ Deprecated bestie_permissions table (permissions now fixed by role)
-- ✅ wedding_profiles: Owner/Partner full access, Bestie view-only
-- ✅ bestie_knowledge: Bestie full access, Owner/Partner ZERO access
-- ✅ bestie_profile: Bestie full access, Owner/Partner ZERO access
-- ✅ chat_messages: Strict separation by message_type
-- ✅ invite_codes: Owner/Partner only
-- ✅ pending_updates: Owner/Partner only
-- ✅ wedding_members: All can view, Owner/Partner can manage
-- ✅ Added documentation comments

-- ============================================================================
-- MIGRATION 014: Correct Wedding Architecture - 4 People with Individual Chats
-- ============================================================================
-- Purpose: Support proper wedding structure while preserving intelligent extraction
-- Architecture:
--   - Wedding Space: Owner + Partner (2 people) with individual chats, shared extraction
--   - Bestie Space: 2 Besties with individual chats, individual bestie_profiles
--   - Total: 4 people maximum per wedding
-- ============================================================================

-- ============================================================================
-- STEP 1: Restore extraction tables (if dropped in migration 013)
-- ============================================================================

-- Restore vendor_tracker table
CREATE TABLE IF NOT EXISTS vendor_tracker (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,

  vendor_type TEXT NOT NULL,
  vendor_name TEXT NOT NULL,
  vendor_contact_name TEXT,
  vendor_email TEXT,
  vendor_phone TEXT,
  vendor_website TEXT,

  -- Financial Tracking
  total_cost NUMERIC(10, 2),
  deposit_amount NUMERIC(10, 2),
  deposit_paid BOOLEAN DEFAULT false,
  deposit_date DATE,
  balance_due NUMERIC(10, 2),
  final_payment_date DATE,
  final_payment_paid BOOLEAN DEFAULT false,

  -- Status & Timeline
  status TEXT CHECK (status IN ('inquiry', 'pending', 'booked', 'contract_signed',
                                'deposit_paid', 'fully_paid', 'rejected', 'cancelled')) DEFAULT 'inquiry',
  contract_signed BOOLEAN DEFAULT false,
  contract_date DATE,
  service_date DATE,

  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendor_tracker_wedding_id ON vendor_tracker(wedding_id);
CREATE INDEX IF NOT EXISTS idx_vendor_tracker_vendor_type ON vendor_tracker(wedding_id, vendor_type);

-- Restore budget_tracker table
CREATE TABLE IF NOT EXISTS budget_tracker (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,

  category TEXT NOT NULL,

  budgeted_amount NUMERIC(10, 2) DEFAULT 0,
  spent_amount NUMERIC(10, 2) DEFAULT 0,
  remaining_amount NUMERIC(10, 2) GENERATED ALWAYS AS (budgeted_amount - spent_amount) STORED,

  last_transaction_date DATE,
  last_transaction_amount NUMERIC(10, 2),
  last_transaction_description TEXT,

  vendor_id UUID REFERENCES vendor_tracker(id) ON DELETE SET NULL,

  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_budget_tracker_wedding_id ON budget_tracker(wedding_id);
CREATE INDEX IF NOT EXISTS idx_budget_tracker_category ON budget_tracker(wedding_id, category);
CREATE UNIQUE INDEX IF NOT EXISTS idx_budget_tracker_unique_category ON budget_tracker(wedding_id, category);

-- Restore wedding_tasks table
CREATE TABLE IF NOT EXISTS wedding_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,

  task_name TEXT NOT NULL,
  task_description TEXT,
  category TEXT,

  due_date DATE,
  completed_date DATE,
  status TEXT CHECK (status IN ('not_started', 'in_progress', 'completed', 'cancelled')) DEFAULT 'not_started',

  assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  priority TEXT CHECK (priority IN ('low', 'medium', 'high', 'urgent')) DEFAULT 'medium',

  vendor_id UUID REFERENCES vendor_tracker(id) ON DELETE SET NULL,

  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wedding_tasks_wedding_id ON wedding_tasks(wedding_id);
CREATE INDEX IF NOT EXISTS idx_wedding_tasks_status ON wedding_tasks(wedding_id, status);
CREATE INDEX IF NOT EXISTS idx_wedding_tasks_due_date ON wedding_tasks(wedding_id, due_date);
CREATE INDEX IF NOT EXISTS idx_wedding_tasks_assigned_to ON wedding_tasks(assigned_to);

-- ============================================================================
-- STEP 2: Update wedding_members to support owner, partner, bestie
-- ============================================================================

-- Update role constraint to include partner
ALTER TABLE wedding_members
DROP CONSTRAINT IF EXISTS wedding_members_role_check;

ALTER TABLE wedding_members
ADD CONSTRAINT wedding_members_role_check
CHECK (role IN ('owner', 'partner', 'bestie'));

-- Add constraint: maximum 1 partner per wedding
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_partner_per_wedding
ON wedding_members (wedding_id)
WHERE role = 'partner';

-- Add constraint: maximum 2 besties per wedding
CREATE OR REPLACE FUNCTION check_bestie_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'bestie' THEN
    IF (SELECT COUNT(*) FROM wedding_members
        WHERE wedding_id = NEW.wedding_id
        AND role = 'bestie') >= 2 THEN
      RAISE EXCEPTION 'Maximum 2 besties allowed per wedding';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_bestie_limit ON wedding_members;

CREATE TRIGGER trigger_check_bestie_limit
  BEFORE INSERT ON wedding_members
  FOR EACH ROW
  EXECUTE FUNCTION check_bestie_limit();

-- ============================================================================
-- STEP 3: Update invite_codes to support partner and bestie
-- ============================================================================

ALTER TABLE invite_codes
DROP CONSTRAINT IF EXISTS invite_codes_role_check;

ALTER TABLE invite_codes
ADD CONSTRAINT invite_codes_role_check
CHECK (role IN ('partner', 'bestie'));

-- ============================================================================
-- STEP 4: Update RLS policies for shared extraction tables
-- ============================================================================

-- Wedding owners (owner + partner) can manage vendors
DROP POLICY IF EXISTS "Users can view vendors for their weddings" ON vendor_tracker;
DROP POLICY IF EXISTS "Users can create vendors for their weddings" ON vendor_tracker;
DROP POLICY IF EXISTS "Users can update vendors for their weddings" ON vendor_tracker;
DROP POLICY IF EXISTS "Users can delete vendors for their weddings" ON vendor_tracker;

CREATE POLICY "Wedding owners can view vendors"
ON vendor_tracker FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = vendor_tracker.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

CREATE POLICY "Wedding owners can create vendors"
ON vendor_tracker FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = vendor_tracker.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

CREATE POLICY "Wedding owners can update vendors"
ON vendor_tracker FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = vendor_tracker.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

CREATE POLICY "Wedding owners can delete vendors"
ON vendor_tracker FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = vendor_tracker.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

-- Wedding owners can manage budget
DROP POLICY IF EXISTS "Users can view budget for their weddings" ON budget_tracker;
DROP POLICY IF EXISTS "Users can create budget for their weddings" ON budget_tracker;
DROP POLICY IF EXISTS "Users can update budget for their weddings" ON budget_tracker;
DROP POLICY IF EXISTS "Users can delete budget for their weddings" ON budget_tracker;

CREATE POLICY "Wedding owners can view budget"
ON budget_tracker FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = budget_tracker.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

CREATE POLICY "Wedding owners can create budget"
ON budget_tracker FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = budget_tracker.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

CREATE POLICY "Wedding owners can update budget"
ON budget_tracker FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = budget_tracker.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

CREATE POLICY "Wedding owners can delete budget"
ON budget_tracker FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = budget_tracker.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

-- Wedding owners can manage tasks
DROP POLICY IF EXISTS "Users can view tasks for their weddings" ON wedding_tasks;
DROP POLICY IF EXISTS "Users can create tasks for their weddings" ON wedding_tasks;
DROP POLICY IF EXISTS "Users can update tasks for their weddings" ON wedding_tasks;
DROP POLICY IF EXISTS "Users can delete tasks for their weddings" ON wedding_tasks;

CREATE POLICY "Wedding owners can view tasks"
ON wedding_tasks FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = wedding_tasks.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

CREATE POLICY "Wedding owners can create tasks"
ON wedding_tasks FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = wedding_tasks.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

CREATE POLICY "Wedding owners can update tasks"
ON wedding_tasks FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = wedding_tasks.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

CREATE POLICY "Wedding owners can delete tasks"
ON wedding_tasks FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM wedding_members
    WHERE wedding_members.wedding_id = wedding_tasks.wedding_id
    AND wedding_members.user_id = auth.uid()
    AND wedding_members.role IN ('owner', 'partner')
  )
);

-- Backend can manage all extraction tables
CREATE POLICY "Backend can manage vendors"
ON vendor_tracker FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

CREATE POLICY "Backend can manage budget"
ON budget_tracker FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

CREATE POLICY "Backend can manage tasks"
ON wedding_tasks FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- STEP 5: Update wedding_profiles RLS for owner + partner
-- ============================================================================

DROP POLICY IF EXISTS "Owners can update their wedding" ON wedding_profiles;

CREATE POLICY "Wedding owners can update wedding"
ON wedding_profiles FOR UPDATE
TO authenticated
USING (
  id IN (
    SELECT wedding_id FROM wedding_members
    WHERE user_id = auth.uid()
    AND role IN ('owner', 'partner')
  )
)
WITH CHECK (
  id IN (
    SELECT wedding_id FROM wedding_members
    WHERE user_id = auth.uid()
    AND role IN ('owner', 'partner')
  )
);

-- ============================================================================
-- STEP 6: Update wedding_members RLS for owner + partner
-- ============================================================================

DROP POLICY IF EXISTS "Owners can update members" ON wedding_members;
DROP POLICY IF EXISTS "Owners and partners can update members" ON wedding_members;

CREATE POLICY "Wedding owners can update members"
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

-- ============================================================================
-- STEP 7: Add triggers for extraction tables
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS vendor_tracker_updated_at ON vendor_tracker;
CREATE TRIGGER vendor_tracker_updated_at
  BEFORE UPDATE ON vendor_tracker
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS budget_tracker_updated_at ON budget_tracker;
CREATE TRIGGER budget_tracker_updated_at
  BEFORE UPDATE ON budget_tracker
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS wedding_tasks_updated_at ON wedding_tasks;
CREATE TRIGGER wedding_tasks_updated_at
  BEFORE UPDATE ON wedding_tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STEP 8: Verification queries
-- ============================================================================

-- Count roles in wedding_members
SELECT
  role,
  COUNT(*) as count
FROM wedding_members
GROUP BY role
ORDER BY role;

-- Verify bestie profiles
SELECT COUNT(*) as bestie_profiles FROM bestie_profile;

-- Verify extraction tables exist
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'vendor_tracker',
    'budget_tracker',
    'wedding_tasks'
  );

-- Check wedding structure (should see max 4 people per wedding)
SELECT
  wedding_id,
  COUNT(*) as total_members,
  COUNT(*) FILTER (WHERE role = 'owner') as owners,
  COUNT(*) FILTER (WHERE role = 'partner') as partners,
  COUNT(*) FILTER (WHERE role = 'bestie') as besties
FROM wedding_members
GROUP BY wedding_id
ORDER BY total_members DESC;

-- ============================================================================
-- COMPLETE
-- ============================================================================
-- Wedding architecture now supports:
-- 1. ✓ Owner + Partner (max 2 people) - Wedding Space with shared extraction
-- 2. ✓ 2 Besties (max 2 people) - Bestie Space with individual profiles
-- 3. ✓ Individual chats per user (via chat_messages.user_id)
-- 4. ✓ Shared vendor/budget/task tables for wedding owners
-- 5. ✓ Intelligent extraction preserved
-- 6. ✓ Maximum 4 people per wedding
-- ============================================================================

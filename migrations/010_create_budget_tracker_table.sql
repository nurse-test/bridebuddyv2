-- Migration: Create budget_tracker table for budget management
-- This allows tracking budget by category with spending vs budget analysis

CREATE TABLE IF NOT EXISTS budget_tracker (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,

  -- Budget category
  category TEXT NOT NULL, -- venue, catering, flowers, photography, videography, music, cake, decorations, attire, invitations, favors, transportation, honeymoon, other

  -- Financial tracking
  budgeted_amount NUMERIC(10, 2) DEFAULT 0,
  spent_amount NUMERIC(10, 2) DEFAULT 0,
  remaining_amount NUMERIC(10, 2) GENERATED ALWAYS AS (budgeted_amount - spent_amount) STORED,

  -- Transaction details (for latest transaction)
  last_transaction_date DATE,
  last_transaction_amount NUMERIC(10, 2),
  last_transaction_description TEXT,

  -- Linked vendor (if applicable)
  vendor_id UUID REFERENCES vendor_tracker(id) ON DELETE SET NULL,

  -- Additional info
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups by wedding
CREATE INDEX idx_budget_tracker_wedding_id ON budget_tracker(wedding_id);

-- Create index for category filtering
CREATE INDEX idx_budget_tracker_category ON budget_tracker(wedding_id, category);

-- Create unique constraint to prevent duplicate categories per wedding
CREATE UNIQUE INDEX idx_budget_tracker_unique_category ON budget_tracker(wedding_id, category);

-- Enable RLS
ALTER TABLE budget_tracker ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view budget for weddings they're members of
CREATE POLICY "Users can view budget for their weddings"
  ON budget_tracker
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = budget_tracker.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Policy: Users can insert budget items for weddings they're members of
CREATE POLICY "Users can create budget items for their weddings"
  ON budget_tracker
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = budget_tracker.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Policy: Users can update budget items for weddings they're members of
CREATE POLICY "Users can update budget items for their weddings"
  ON budget_tracker
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = budget_tracker.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Policy: Users can delete budget items for weddings they're members of
CREATE POLICY "Users can delete budget items for their weddings"
  ON budget_tracker
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = budget_tracker.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_budget_tracker_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function
CREATE TRIGGER budget_tracker_updated_at
  BEFORE UPDATE ON budget_tracker
  FOR EACH ROW
  EXECUTE FUNCTION update_budget_tracker_updated_at();

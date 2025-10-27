-- Migration: Create vendor_tracker table for detailed vendor management
-- This allows tracking individual vendors with deposits, payments, and status

CREATE TABLE IF NOT EXISTS vendor_tracker (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,

  -- Vendor details
  vendor_type TEXT NOT NULL, -- photographer, caterer, florist, dj, baker, venue, planner, etc.
  vendor_name TEXT NOT NULL,
  vendor_contact_name TEXT,
  vendor_email TEXT,
  vendor_phone TEXT,
  vendor_website TEXT,

  -- Financial tracking
  total_cost NUMERIC(10, 2),
  deposit_amount NUMERIC(10, 2),
  deposit_paid BOOLEAN DEFAULT false,
  deposit_date DATE,
  balance_due NUMERIC(10, 2),
  final_payment_date DATE,
  final_payment_paid BOOLEAN DEFAULT false,

  -- Status and timeline
  status TEXT CHECK (status IN ('inquiry', 'pending', 'booked', 'contract_signed', 'deposit_paid', 'fully_paid', 'rejected', 'cancelled')) DEFAULT 'inquiry',
  contract_signed BOOLEAN DEFAULT false,
  contract_date DATE,
  service_date DATE,

  -- Additional info
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups by wedding
CREATE INDEX idx_vendor_tracker_wedding_id ON vendor_tracker(wedding_id);

-- Create index for vendor type filtering
CREATE INDEX idx_vendor_tracker_vendor_type ON vendor_tracker(wedding_id, vendor_type);

-- Enable RLS
ALTER TABLE vendor_tracker ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view vendors for weddings they're members of
CREATE POLICY "Users can view vendors for their weddings"
  ON vendor_tracker
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = vendor_tracker.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Policy: Users can insert vendors for weddings they're members of
CREATE POLICY "Users can create vendors for their weddings"
  ON vendor_tracker
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = vendor_tracker.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Policy: Users can update vendors for weddings they're members of
CREATE POLICY "Users can update vendors for their weddings"
  ON vendor_tracker
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = vendor_tracker.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Policy: Users can delete vendors for weddings they're members of
CREATE POLICY "Users can delete vendors for their weddings"
  ON vendor_tracker
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = vendor_tracker.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_vendor_tracker_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function
CREATE TRIGGER vendor_tracker_updated_at
  BEFORE UPDATE ON vendor_tracker
  FOR EACH ROW
  EXECUTE FUNCTION update_vendor_tracker_updated_at();

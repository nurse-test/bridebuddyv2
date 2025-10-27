-- Migration: Create wedding_tasks table for timeline and task management
-- This allows tracking wedding planning tasks, deadlines, and progress

CREATE TABLE IF NOT EXISTS wedding_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,

  -- Task details
  task_name TEXT NOT NULL,
  task_description TEXT,
  category TEXT, -- venue, catering, flowers, photography, attire, invitations, decorations, transportation, legal, honeymoon, day-of, other

  -- Timeline tracking
  due_date DATE,
  completed_date DATE,
  status TEXT CHECK (status IN ('not_started', 'in_progress', 'completed', 'cancelled')) DEFAULT 'not_started',

  -- Assignment
  assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Priority
  priority TEXT CHECK (priority IN ('low', 'medium', 'high', 'urgent')) DEFAULT 'medium',

  -- Linked vendor (if applicable)
  vendor_id UUID REFERENCES vendor_tracker(id) ON DELETE SET NULL,

  -- Additional info
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups by wedding
CREATE INDEX idx_wedding_tasks_wedding_id ON wedding_tasks(wedding_id);

-- Create index for status filtering
CREATE INDEX idx_wedding_tasks_status ON wedding_tasks(wedding_id, status);

-- Create index for due date sorting
CREATE INDEX idx_wedding_tasks_due_date ON wedding_tasks(wedding_id, due_date);

-- Create index for assigned tasks
CREATE INDEX idx_wedding_tasks_assigned_to ON wedding_tasks(assigned_to);

-- Enable RLS
ALTER TABLE wedding_tasks ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view tasks for weddings they're members of
CREATE POLICY "Users can view tasks for their weddings"
  ON wedding_tasks
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = wedding_tasks.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Policy: Users can insert tasks for weddings they're members of
CREATE POLICY "Users can create tasks for their weddings"
  ON wedding_tasks
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = wedding_tasks.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Policy: Users can update tasks for weddings they're members of
CREATE POLICY "Users can update tasks for their weddings"
  ON wedding_tasks
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = wedding_tasks.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Policy: Users can delete tasks for weddings they're members of
CREATE POLICY "Users can delete tasks for their weddings"
  ON wedding_tasks
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM wedding_members
      WHERE wedding_members.wedding_id = wedding_tasks.wedding_id
      AND wedding_members.user_id = auth.uid()
    )
  );

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_wedding_tasks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function
CREATE TRIGGER wedding_tasks_updated_at
  BEFORE UPDATE ON wedding_tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_wedding_tasks_updated_at();

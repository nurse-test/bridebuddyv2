-- ============================================================================
-- MIGRATION 003: Create bestie_knowledge table
-- ============================================================================
-- Purpose: Dedicated storage for bestie's private planning knowledge
-- Separate from chat_messages (structured data vs conversational)
-- Part of: Phase 1 - Bestie Permission System Implementation
-- ============================================================================

-- ============================================================================
-- STEP 1: Create bestie_knowledge table
-- ============================================================================

CREATE TABLE IF NOT EXISTS bestie_knowledge (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- The bestie who owns this knowledge
  bestie_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- The wedding this knowledge relates to
  wedding_id UUID NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE,

  -- The actual knowledge content
  content TEXT NOT NULL,

  -- Type of knowledge for categorization
  knowledge_type TEXT NOT NULL DEFAULT 'note'
    CHECK (knowledge_type IN ('note', 'vendor', 'task', 'expense', 'idea', 'checklist', 'contact')),

  -- Privacy flag - if true, only bestie can see (even if inviter has can_read)
  is_private BOOLEAN DEFAULT FALSE,

  -- Additional metadata (flexible for future expansion)
  metadata JSONB DEFAULT '{}'::jsonb,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- STEP 2: Create indexes for performance
-- ============================================================================

-- Index for looking up bestie's knowledge (most common query)
CREATE INDEX IF NOT EXISTS bestie_knowledge_bestie_idx
ON bestie_knowledge(bestie_user_id);

-- Index for wedding-based queries
CREATE INDEX IF NOT EXISTS bestie_knowledge_wedding_idx
ON bestie_knowledge(wedding_id);

-- Index for filtering by type
CREATE INDEX IF NOT EXISTS bestie_knowledge_type_idx
ON bestie_knowledge(knowledge_type);

-- Index for privacy filtering
CREATE INDEX IF NOT EXISTS bestie_knowledge_private_idx
ON bestie_knowledge(is_private);

-- Composite index for most common query pattern
CREATE INDEX IF NOT EXISTS bestie_knowledge_bestie_wedding_idx
ON bestie_knowledge(bestie_user_id, wedding_id);

-- Index for created_at (for sorting)
CREATE INDEX IF NOT EXISTS bestie_knowledge_created_at_idx
ON bestie_knowledge(created_at DESC);

-- Full text search index on content
CREATE INDEX IF NOT EXISTS bestie_knowledge_content_search_idx
ON bestie_knowledge USING GIN (to_tsvector('english', content));

-- ============================================================================
-- STEP 3: Add trigger for updated_at timestamp
-- ============================================================================

-- Create trigger to auto-update updated_at
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
-- STEP 4: Add comments for documentation
-- ============================================================================

COMMENT ON TABLE bestie_knowledge IS
'Dedicated storage for bestie''s (MOH/Best Man) private planning knowledge. Separate from chat_messages for structured, categorized data like vendor info, tasks, expenses, etc.';

COMMENT ON COLUMN bestie_knowledge.bestie_user_id IS
'The bestie (MOH/Best Man) who owns this knowledge entry.';

COMMENT ON COLUMN bestie_knowledge.content IS
'The actual knowledge content. Can be text, notes, vendor details, task descriptions, etc.';

COMMENT ON COLUMN bestie_knowledge.knowledge_type IS
'Category of knowledge: note (general), vendor (vendor info), task (todo item), expense (cost tracking), idea (brainstorming), checklist (itemized list), contact (person info).';

COMMENT ON COLUMN bestie_knowledge.is_private IS
'If true, only the bestie can see this entry even if inviter has can_read permission. Use for ultra-private surprise planning.';

COMMENT ON COLUMN bestie_knowledge.metadata IS
'Flexible JSONB field for additional structured data. Examples: {"priority": "high"}, {"cost": 500, "paid": false}, {"contact_phone": "555-1234"}.';

-- ============================================================================
-- STEP 5: Add helper functions
-- ============================================================================

-- Function to search bestie knowledge by text
CREATE OR REPLACE FUNCTION search_bestie_knowledge(
  p_bestie_user_id UUID,
  p_search_term TEXT
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  knowledge_type TEXT,
  created_at TIMESTAMPTZ,
  rank REAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    bk.id,
    bk.content,
    bk.knowledge_type,
    bk.created_at,
    ts_rank(to_tsvector('english', bk.content), plainto_tsquery('english', p_search_term)) as rank
  FROM bestie_knowledge bk
  WHERE bk.bestie_user_id = p_bestie_user_id
    AND to_tsvector('english', bk.content) @@ plainto_tsquery('english', p_search_term)
  ORDER BY rank DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get knowledge summary by type
CREATE OR REPLACE FUNCTION get_bestie_knowledge_summary(
  p_bestie_user_id UUID,
  p_wedding_id UUID
)
RETURNS TABLE (
  knowledge_type TEXT,
  count BIGINT,
  latest_created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    bk.knowledge_type,
    COUNT(*) as count,
    MAX(bk.created_at) as latest_created_at
  FROM bestie_knowledge bk
  WHERE bk.bestie_user_id = p_bestie_user_id
    AND bk.wedding_id = p_wedding_id
  GROUP BY bk.knowledge_type
  ORDER BY count DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 6: Verification queries
-- ============================================================================

-- Check table structure
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'bestie_knowledge'
ORDER BY ordinal_position;

-- Check indexes were created
SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'bestie_knowledge'
ORDER BY indexname;

-- Check constraints
SELECT
  con.conname AS constraint_name,
  con.contype AS constraint_type,
  pg_get_constraintdef(con.oid) AS constraint_definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'bestie_knowledge'
ORDER BY con.conname;

-- Count any existing knowledge entries
SELECT COUNT(*) as total_knowledge_entries FROM bestie_knowledge;

-- ============================================================================
-- STEP 7: Sample data for testing (commented out)
-- ============================================================================
/*
-- Uncomment to insert sample data for testing

-- Insert sample knowledge entries
INSERT INTO bestie_knowledge (bestie_user_id, wedding_id, content, knowledge_type, is_private)
VALUES
  ('BESTIE_USER_ID', 'WEDDING_ID', 'Surprise bachelorette party at Vegas - don''t tell bride!', 'note', true),
  ('BESTIE_USER_ID', 'WEDDING_ID', 'Photographer: Sarah''s Photography, $2000, booked for Saturday', 'vendor', false),
  ('BESTIE_USER_ID', 'WEDDING_ID', 'Order bridesmaid dresses by March 15th', 'task', false),
  ('BESTIE_USER_ID', 'WEDDING_ID', 'Total bachelorette budget: $3500', 'expense', false),
  ('BESTIE_USER_ID', 'WEDDING_ID', 'Maybe do a spa day instead of nightclub?', 'idea', false);

-- Test search function
SELECT * FROM search_bestie_knowledge('BESTIE_USER_ID', 'bachelorette');

-- Test summary function
SELECT * FROM get_bestie_knowledge_summary('BESTIE_USER_ID', 'WEDDING_ID');
*/

-- ============================================================================
-- ROLLBACK (if needed - run this to undo migration)
-- ============================================================================
/*
-- Uncomment to rollback this migration

-- Drop functions
DROP FUNCTION IF EXISTS search_bestie_knowledge(UUID, TEXT);
DROP FUNCTION IF EXISTS get_bestie_knowledge_summary(UUID, UUID);

-- Drop trigger and function
DROP TRIGGER IF EXISTS trigger_update_bestie_knowledge_updated_at ON bestie_knowledge;
DROP FUNCTION IF EXISTS update_bestie_knowledge_updated_at();

-- Drop indexes
DROP INDEX IF EXISTS bestie_knowledge_bestie_idx;
DROP INDEX IF EXISTS bestie_knowledge_wedding_idx;
DROP INDEX IF EXISTS bestie_knowledge_type_idx;
DROP INDEX IF EXISTS bestie_knowledge_private_idx;
DROP INDEX IF EXISTS bestie_knowledge_bestie_wedding_idx;
DROP INDEX IF EXISTS bestie_knowledge_created_at_idx;
DROP INDEX IF EXISTS bestie_knowledge_content_search_idx;

-- Drop table
DROP TABLE IF EXISTS bestie_knowledge CASCADE;
*/

-- ============================================================================
-- COMPLETE
-- ============================================================================
-- bestie_knowledge table created with:
-- 1. Structured storage for bestie's planning knowledge
-- 2. Categorization by type (note, vendor, task, expense, etc.)
-- 3. Privacy flag for ultra-private surprises
-- 4. Full text search capability
-- 5. Helper functions for search and summaries
-- 6. All indexes for efficient queries
--
-- Next: Run 004_rls_bestie_permissions.sql
-- ============================================================================

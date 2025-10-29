-- ============================================================================
-- DATABASE SCHEMA INSPECTION
-- ============================================================================
-- This query shows ALL tables in the public schema with their column structures
--
-- USAGE:
--   1. Copy this entire file
--   2. Paste into Supabase SQL Editor
--   3. Execute to see complete schema
-- ============================================================================

SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

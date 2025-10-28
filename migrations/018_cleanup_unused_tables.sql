-- ============================================================================
-- MIGRATION 018: CLEANUP UNUSED TABLES
-- ============================================================================
-- Purpose: Remove 4 tables that are not referenced anywhere in the codebase
-- Created: 2025-10-28
-- Safe to run: YES - These tables are not used by any application code
-- ============================================================================

-- TABLES BEING REMOVED:
-- 1. attire - Only referenced as enum category, no actual table queries
-- 2. bestie_knowledge - Created but never populated or queried
-- 3. daily_message_counts - Not found anywhere in codebase
-- 4. pending_vendors - Not found anywhere in codebase

-- ============================================================================
-- DROP UNUSED TABLES
-- ============================================================================

-- Drop attire table (if exists)
-- This table was never used - attire is tracked as a category in budget_tracker
DROP TABLE IF EXISTS attire CASCADE;

-- Drop bestie_knowledge table (if exists)
-- This table was created in old architecture but never actually used
DROP TABLE IF EXISTS bestie_knowledge CASCADE;

-- Drop daily_message_counts table (if exists)
-- This table is not referenced anywhere in the application
DROP TABLE IF EXISTS daily_message_counts CASCADE;

-- Drop pending_vendors table (if exists)
-- Vendors are tracked directly in vendor_tracker without approval workflow
DROP TABLE IF EXISTS pending_vendors CASCADE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After running this migration, verify the remaining tables with:
--
-- SELECT table_name
-- FROM information_schema.tables
-- WHERE table_schema = 'public'
-- AND table_type = 'BASE TABLE'
-- ORDER BY table_name;
--
-- Expected tables (11 total):
-- 1. bestie_permissions
-- 2. bestie_profile
-- 3. budget_tracker
-- 4. chat_messages
-- 5. invite_codes
-- 6. pending_updates
-- 7. profiles
-- 8. vendor_tracker
-- 9. wedding_members
-- 10. wedding_profiles
-- 11. wedding_tasks
-- ============================================================================

-- Log successful migration
DO $$
BEGIN
  RAISE NOTICE 'Migration 018 completed: Removed 4 unused tables (attire, bestie_knowledge, daily_message_counts, pending_vendors)';
END $$;

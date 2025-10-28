-- Check if bestie_profile table exists
SELECT
  table_name,
  table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'bestie_profile';

-- Check what constraints exist with this name
SELECT
  conname AS constraint_name,
  conrelid::regclass AS table_name,
  contype AS constraint_type
FROM pg_constraint
WHERE conname = 'unique_bestie_per_wedding';

-- Check all columns if table exists
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'bestie_profile'
ORDER BY ordinal_position;

-- Check all constraints on bestie_profile if it exists
SELECT
  tc.constraint_name,
  tc.constraint_type
FROM information_schema.table_constraints tc
WHERE tc.table_name = 'bestie_profile';

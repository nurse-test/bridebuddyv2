-- Migration: Add color_scheme_secondary column to wedding_profiles
-- This column was referenced in the extraction prompt but was missing from the schema

ALTER TABLE wedding_profiles
ADD COLUMN IF NOT EXISTS color_scheme_secondary TEXT;

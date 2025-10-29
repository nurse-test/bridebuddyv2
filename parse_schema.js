#!/usr/bin/env node

/**
 * Parse Database Schema from SQL Files
 *
 * This script parses database_init.sql and migration files to extract
 * table schemas and display them in a readable format.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Read the database init file
const dbInitPath = path.join(__dirname, 'database_init.sql');
const sqlContent = fs.readFileSync(dbInitPath, 'utf8');

// Parse CREATE TABLE statements
const tableRegex = /CREATE TABLE IF NOT EXISTS (\w+)\s*\(([\s\S]*?)\);/gi;
const tables = new Map();

let match;
while ((match = tableRegex.exec(sqlContent)) !== null) {
  const tableName = match[1];
  const tableDefinition = match[2];

  // Parse columns
  const columns = [];
  const lines = tableDefinition.split(',').map(l => l.trim());

  for (const line of lines) {
    // Skip constraints and other non-column definitions
    if (line.startsWith('PRIMARY KEY') ||
        line.startsWith('FOREIGN KEY') ||
        line.startsWith('CONSTRAINT') ||
        line.startsWith('CHECK') ||
        line.startsWith('UNIQUE')) {
      continue;
    }

    // Extract column information
    const columnMatch = line.match(/^(\w+)\s+([A-Z0-9()]+(?:\s+[A-Z]+)*)(.*)?/i);
    if (columnMatch) {
      const columnName = columnMatch[1];
      const dataType = columnMatch[2].trim();
      const constraints = columnMatch[3] ? columnMatch[3].trim() : '';

      columns.push({
        name: columnName,
        type: dataType,
        constraints: constraints
      });
    }
  }

  if (columns.length > 0) {
    tables.set(tableName, columns);
  }
}

// Display results
console.log('\n' + '='.repeat(100));
console.log('DATABASE SCHEMA - ALL TABLES');
console.log('='.repeat(100));
console.log(`\nFound ${tables.size} tables in database_init.sql\n`);

for (const [tableName, columns] of tables.entries()) {
  console.log('\n' + '─'.repeat(100));
  console.log(`TABLE: ${tableName.toUpperCase()}`);
  console.log('─'.repeat(100));
  console.log('');
  console.log('Column Name'.padEnd(30) + 'Data Type'.padEnd(25) + 'Constraints');
  console.log('-'.repeat(100));

  for (const col of columns) {
    const constraintStr = col.constraints.length > 40
      ? col.constraints.substring(0, 37) + '...'
      : col.constraints;

    console.log(
      col.name.padEnd(30) +
      col.type.padEnd(25) +
      constraintStr
    );
  }
}

console.log('\n' + '='.repeat(100));
console.log(`Total: ${tables.size} tables`);
console.log('='.repeat(100));
console.log('\nTo get live data from your Supabase database:');
console.log('  1. Run: node inspect_database_schema.js');
console.log('  2. Or copy show_all_tables_schema.sql into Supabase SQL Editor\n');

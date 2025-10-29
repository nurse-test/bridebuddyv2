import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables from .env file if it exists
const dotenvPath = path.join(__dirname, '.env');
if (fs.existsSync(dotenvPath)) {
  const dotenvContent = fs.readFileSync(dotenvPath, 'utf8');
  dotenvContent.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...valueParts] = trimmed.split('=');
      if (key && valueParts.length > 0) {
        const value = valueParts.join('=').trim();
        if (!process.env[key]) {
          process.env[key] = value;
        }
      }
    }
  });
}

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Error: Missing required environment variables');
  console.error('Please ensure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function inspectDatabaseSchema() {
  console.log('Fetching all tables and their column structures...\n');

  const query = `
    SELECT
      table_name,
      column_name,
      data_type,
      is_nullable,
      column_default
    FROM information_schema.columns
    WHERE table_schema = 'public'
    ORDER BY table_name, ordinal_position;
  `;

  try {
    // Use Supabase REST API to execute raw SQL
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseServiceKey,
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'Prefer': 'return=representation'
      },
      body: JSON.stringify({ query })
    });

    if (!response.ok) {
      console.error('Error querying database:', response.status, response.statusText);
      console.log('\nNote: If the exec_sql function does not exist, you may need to create it in Supabase.');
      console.log('Trying alternative method: querying tables directly...\n');

      // Alternative: Query each table individually
      await queryTablesDirectly();
      return;
    }

    const data = await response.json();
    displayResults(data);
  } catch (error) {
    console.error('Error executing query:', error.message);
    console.log('\nTrying alternative method: querying tables directly...\n');
    await queryTablesDirectly();
  }
}

async function queryTablesDirectly() {
  // Get list of all tables from the Supabase metadata
  // We'll use the public schema tables that we know exist from migrations
  const knownTables = [
    'profiles',
    'wedding_profiles',
    'wedding_members',
    'invites',
    'bestie_permissions',
    'bestie_knowledge',
    'vendor_tracker',
    'budget_tracker',
    'wedding_tasks',
    'messages'
  ];

  console.log('Querying known tables from the codebase...\n');

  for (const tableName of knownTables) {
    try {
      // Query just one row to get the structure
      const { data, error } = await supabase
        .from(tableName)
        .select('*')
        .limit(1);

      if (error) {
        console.log(`Table "${tableName}": Not accessible or doesn't exist`);
        continue;
      }

      if (data && data.length > 0) {
        const columns = Object.keys(data[0]);
        console.log(`\nTable: ${tableName}`);
        console.log('-'.repeat(80));
        console.log('Columns:', columns.join(', '));
      } else {
        console.log(`\nTable: ${tableName} (exists but empty)`);
      }
    } catch (err) {
      console.log(`Table "${tableName}": Error - ${err.message}`);
    }
  }
}

function displayResults(data) {
  if (!data || data.length === 0) {
    console.log('No tables found in the public schema.');
    return;
  }

  // Group by table
  const tableMap = new Map();

  data.forEach(row => {
    if (!tableMap.has(row.table_name)) {
      tableMap.set(row.table_name, []);
    }
    tableMap.get(row.table_name).push({
      column: row.column_name,
      type: row.data_type,
      nullable: row.is_nullable === 'YES' ? 'NULL' : 'NOT NULL',
      default: row.column_default || ''
    });
  });

  console.log(`Found ${tableMap.size} tables in the database:\n`);
  console.log('='.repeat(80));

  for (const [tableName, columns] of tableMap.entries()) {
    console.log(`\nTable: ${tableName}`);
    console.log('-'.repeat(80));
    console.log('Column Name'.padEnd(30) + 'Data Type'.padEnd(25) + 'Nullable'.padEnd(15) + 'Default');
    console.log('-'.repeat(80));

    columns.forEach(col => {
      console.log(
        col.column.padEnd(30) +
        col.type.padEnd(25) +
        col.nullable.padEnd(15) +
        (col.default.length > 20 ? col.default.substring(0, 17) + '...' : col.default)
      );
    });

    console.log('='.repeat(80));
  }

  console.log(`\nTotal tables: ${tableMap.size}`);
  console.log(`Total columns across all tables: ${data.length}`);
}

// Run the inspection
inspectDatabaseSchema().catch(error => {
  console.error('Unexpected error:', error);
  process.exit(1);
});

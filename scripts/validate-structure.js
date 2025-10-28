#!/usr/bin/env node

/**
 * Validates project structure and critical files
 * Ensures required directories and files exist
 */

import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.join(__dirname, '..');

// Critical paths that must exist
const requiredPaths = [
  { path: 'api', type: 'directory', description: 'Vercel API functions' },
  { path: 'public', type: 'directory', description: 'Static assets' },
  { path: 'public/js', type: 'directory', description: 'Frontend JavaScript' },
  { path: 'public/css', type: 'directory', description: 'Stylesheets' },
  { path: 'vercel.json', type: 'file', description: 'Vercel configuration' },
  { path: '.env.example', type: 'file', description: 'Environment template' },
  { path: 'package.json', type: 'file', description: 'NPM configuration' }
];

// Files that should NOT be committed
const forbiddenFiles = [
  { path: '.env', description: 'Environment file (contains secrets)' },
  { path: 'public/js/config.js', description: 'Generated config (contains API keys)' }
];

let hasErrors = false;

console.log('Validating project structure...\n');

// Check required paths
for (const item of requiredPaths) {
  const fullPath = path.join(rootDir, item.path);
  try {
    const stat = await fs.stat(fullPath);
    const isCorrectType =
      (item.type === 'directory' && stat.isDirectory()) ||
      (item.type === 'file' && stat.isFile());

    if (!isCorrectType) {
      console.error(`❌ ${item.path} - Expected ${item.type}, found ${stat.isDirectory() ? 'directory' : 'file'}`);
      hasErrors = true;
    } else {
      console.log(`✓ ${item.path} - ${item.description}`);
    }
  } catch (error) {
    console.error(`❌ ${item.path} - Missing (${item.description})`);
    hasErrors = true;
  }
}

console.log('\nChecking for accidentally committed secrets...\n');

// Check for forbidden files
for (const item of forbiddenFiles) {
  const fullPath = path.join(rootDir, item.path);
  try {
    await fs.access(fullPath);
    // File exists - this is OK locally, but we should verify it's gitignored
    console.log(`⚠️  ${item.path} exists locally (${item.description})`);
    console.log(`   Ensure it's listed in .gitignore`);
  } catch (error) {
    // File doesn't exist - this is good for security
    console.log(`✓ ${item.path} - Not present (good)`);
  }
}

// Verify .gitignore exists and contains critical patterns
console.log('\nValidating .gitignore...\n');

try {
  const gitignorePath = path.join(rootDir, '.gitignore');
  const gitignoreContent = await fs.readFile(gitignorePath, 'utf-8');

  const requiredPatterns = [
    { pattern: '.env', description: 'Environment variables' },
    { pattern: 'node_modules', description: 'Node modules' },
    { pattern: 'config.js', description: 'Generated config' }
  ];

  for (const item of requiredPatterns) {
    if (gitignoreContent.includes(item.pattern)) {
      console.log(`✓ .gitignore includes "${item.pattern}" (${item.description})`);
    } else {
      console.error(`❌ .gitignore missing "${item.pattern}" (${item.description})`);
      hasErrors = true;
    }
  }
} catch (error) {
  console.error('❌ .gitignore not found or unreadable');
  hasErrors = true;
}

console.log('\n' + '='.repeat(50));

if (hasErrors) {
  console.error('\n❌ Validation failed - please fix the errors above\n');
  process.exit(1);
} else {
  console.log('\n✓ All validation checks passed\n');
  process.exit(0);
}

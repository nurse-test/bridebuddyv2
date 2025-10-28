#!/usr/bin/env node

/**
 * Scans codebase for potential secrets and security issues
 * Checks for hardcoded API keys, passwords, and security anti-patterns
 */

import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.join(__dirname, '..');

// Patterns that indicate potential secrets
const secretPatterns = [
  { regex: /['"](sk_live_[a-zA-Z0-9]{24,})['"]/g, description: 'Stripe live secret key' },
  { regex: /['"](pk_live_[a-zA-Z0-9]{24,})['"]/g, description: 'Stripe live public key' },
  { regex: /['"](rk_live_[a-zA-Z0-9]{24,})['"]/g, description: 'Stripe restricted key' },
  { regex: /['"](eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})['"]/g, description: 'JWT token' },
  { regex: /ANTHROPIC_API_KEY\s*=\s*['"]sk-ant-[^'"]+['"]/g, description: 'Hardcoded Anthropic API key' },
  { regex: /SUPABASE_SERVICE_ROLE_KEY\s*=\s*['"]eyJ[^'"]+['"]/g, description: 'Hardcoded Supabase service role key' }
];

// Directories to scan
const dirsToScan = ['api', 'public/js', 'scripts'];

// Files to skip
const skipPatterns = [
  /node_modules/,
  /\.git/,
  /config\.js$/,  // Generated file
  /check-secrets\.js$/,  // This script
  /\.example\./,  // Example files
  /\.md$/  // Documentation
];

let issuesFound = 0;

async function scanFile(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    const relativePath = path.relative(rootDir, filePath);

    for (const pattern of secretPatterns) {
      const matches = Array.from(content.matchAll(pattern.regex));
      if (matches.length > 0) {
        for (const match of matches) {
          // Skip false positives (example values, placeholders)
          const matchedText = match[0];
          if (matchedText.includes('your_') ||
              matchedText.includes('YOUR_') ||
              matchedText.includes('example') ||
              matchedText.includes('EXAMPLE') ||
              matchedText.includes('placeholder') ||
              matchedText.includes('xxx')) {
            continue;
          }

          console.error(`❌ ${relativePath}`);
          console.error(`   ${pattern.description}`);
          console.error(`   Line contains: ${matchedText.substring(0, 50)}...`);
          console.error('');
          issuesFound++;
        }
      }
    }
  } catch (error) {
    // Skip unreadable files
  }
}

async function scanDirectory(dir) {
  try {
    const entries = await fs.readdir(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);

      // Skip if matches skip patterns
      if (skipPatterns.some(pattern => pattern.test(fullPath))) {
        continue;
      }

      if (entry.isDirectory()) {
        await scanDirectory(fullPath);
      } else if (entry.isFile() && (entry.name.endsWith('.js') || entry.name.endsWith('.html'))) {
        await scanFile(fullPath);
      }
    }
  } catch (error) {
    // Skip inaccessible directories
  }
}

console.log('Scanning for hardcoded secrets and API keys...\n');

for (const dir of dirsToScan) {
  const fullPath = path.join(rootDir, dir);
  try {
    await fs.access(fullPath);
    console.log(`Scanning ${dir}/...`);
    await scanDirectory(fullPath);
  } catch (error) {
    console.warn(`⚠️  Skipping ${dir}/ (not found)`);
  }
}

console.log('\n' + '='.repeat(50));

if (issuesFound > 0) {
  console.error(`\n❌ Found ${issuesFound} potential secret(s) in code`);
  console.error('Please remove hardcoded secrets and use environment variables\n');
  process.exit(1);
} else {
  console.log('\n✓ No hardcoded secrets detected\n');
  process.exit(0);
}

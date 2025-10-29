#!/usr/bin/env node

/**
 * Robust npm audit script for CI/CD environments
 * Handles common issues with package tree validation
 */

import { execSync } from 'child_process';
import { existsSync } from 'fs';
import { exit } from 'process';

const AUDIT_LEVEL = process.env.AUDIT_LEVEL || 'moderate';

console.log('🔍 Running npm security audit...\n');

// Step 1: Verify package files exist
console.log('Step 1: Verifying package files...');
if (!existsSync('package.json')) {
    console.error('❌ package.json not found');
    exit(1);
}
if (!existsSync('package-lock.json')) {
    console.error('❌ package-lock.json not found');
    exit(1);
}
console.log('✓ Package files exist\n');

// Step 2: Verify node_modules exists
console.log('Step 2: Verifying node_modules...');
if (!existsSync('node_modules')) {
    console.error('❌ node_modules not found');
    console.error('   Run "npm install" or "npm ci" first');
    exit(1);
}
console.log('✓ node_modules exists\n');

// Step 3: Verify package tree is valid
console.log('Step 3: Verifying package tree...');
try {
    execSync('npm ls --depth=0', {
        encoding: 'utf8',
        stdio: 'pipe'
    });
    console.log('✓ Package tree is valid\n');
} catch (error) {
    console.error('❌ Package tree has issues:');
    console.error(error.stdout || error.message);
    console.error('\nTrying to continue anyway...\n');
}

// Step 4: Run npm audit
console.log(`Step 4: Running npm audit (level: ${AUDIT_LEVEL})...\n`);
try {
    const output = execSync(`npm audit --audit-level=${AUDIT_LEVEL}`, {
        encoding: 'utf8',
        stdio: 'pipe'
    });
    console.log(output);
    console.log('✅ No vulnerabilities found!\n');
    exit(0);
} catch (error) {
    // npm audit returns exit code 1 if vulnerabilities are found
    if (error.stdout) {
        console.log(error.stdout);
    }
    if (error.stderr) {
        console.error(error.stderr);
    }

    // Check if this is an audit endpoint error
    if (error.message.includes('audit endpoint returned an error')) {
        console.error('\n❌ npm audit endpoint error');
        console.error('This usually means:');
        console.error('1. Package tree is invalid - run "npm ci" to rebuild');
        console.error('2. npm registry is temporarily unavailable');
        console.error('3. Network connectivity issues\n');
        exit(1);
    }

    // Check if vulnerabilities were found (normal audit failure)
    if (error.message.includes('vulnerabilities')) {
        console.error('\n❌ Security vulnerabilities found!');
        console.error('Run "npm audit fix" to attempt automatic fixes\n');
        exit(1);
    }

    // Unknown error
    console.error('\n❌ npm audit failed with unknown error');
    console.error(error.message);
    exit(1);
}

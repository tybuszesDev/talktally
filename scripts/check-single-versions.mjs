#!/usr/bin/env node
// Fails when the lockfile resolves more than one version of a package that must be unique.
// React Native requires one exact React version, so web and mobile must share it.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const MUST_BE_SINGLE = ['react', 'react-dom', 'typescript'];

const lockfile = readFileSync(fileURLToPath(new URL('../pnpm-lock.yaml', import.meta.url)), 'utf8');

// Lockfile entries look like `  react@19.3.0:` or `  '@types/react@19.3.1':`
const entry = /^ {2}'?((?:@[^/\s]+\/)?[^@'\s]+)@([^('\s:]+)/;

const versions = new Map(MUST_BE_SINGLE.map((name) => [name, new Set()]));
for (const line of lockfile.split('\n')) {
  const match = entry.exec(line);
  if (match && versions.has(match[1])) versions.get(match[1]).add(match[2]);
}

const duplicates = [...versions].filter(([, found]) => found.size > 1);
for (const [name, found] of versions) {
  console.log(`${name}: ${[...found].join(', ') || 'not installed'}`);
}
if (duplicates.length > 0) {
  console.error(`More than one version installed: ${duplicates.map(([name]) => name).join(', ')}`);
  process.exitCode = 1;
}

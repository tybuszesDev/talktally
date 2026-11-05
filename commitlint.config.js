// Conventional Commits rules from ADR-0012, checked by the commit-msg hook.

import { readdirSync } from 'node:fs';

// Scopes are workspace names (folders in apps/, packages/ and services/) plus `infra`.
const workspaceScopes = ['apps', 'packages', 'services'].flatMap((folder) => {
  try {
    return readdirSync(new URL(folder, import.meta.url), { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name);
  } catch {
    return []; // The folder does not exist yet.
  }
});

/** @type {import('@commitlint/types').UserConfig} */
const config = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      ['feat', 'fix', 'refactor', 'test', 'docs', 'chore', 'ci', 'build', 'perf'],
    ],
    'scope-enum': [2, 'always', [...workspaceScopes, 'infra']],
  },
};

export default config;

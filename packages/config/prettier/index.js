// Shared Prettier settings. Formatting runs only in the pre-commit hook and in CI (F-02).

import { fileURLToPath } from 'node:url';

/** @type {import('prettier').Config} */
const config = {
  singleQuote: true,
  printWidth: 100,
  // Resolved here, so workspaces that re-export this config do not need the plugin themselves.
  // The Tailwind plugin must be the last plugin in the list.
  plugins: [fileURLToPath(import.meta.resolve('prettier-plugin-tailwindcss'))],
};

export default config;

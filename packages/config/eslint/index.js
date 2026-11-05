// Shared ESLint flat config presets (ADR-0017). Each workspace has an eslint.config.js like:
//   import { web } from '@talktally/config/eslint';
//   export default web({ tsconfigRootDir: import.meta.dirname });
// ESLint looks up the config from each file's directory, so running ESLint from the repository
// root (the pre-commit hook) uses the nearest workspace config.

import js from '@eslint/js';
import prettier from 'eslint-config-prettier';
import jsxA11y from 'eslint-plugin-jsx-a11y-x';
import reactHooks from 'eslint-plugin-react-hooks';
import reactNativeA11y from 'eslint-plugin-react-native-a11y';
import globals from 'globals';
import tseslint from 'typescript-eslint';

/**
 * @typedef {import('eslint').Linter.Config} Config
 * @typedef {{ tsconfigRootDir: string }} Options
 */

const jsFiles = ['**/*.{js,mjs,cjs}'];
const jsxFiles = ['**/*.{jsx,tsx}'];

/**
 * TypeScript with type information, for every workspace.
 * @param {Options} options
 * @returns {Config[]}
 */
export function base({ tsconfigRootDir }) {
  return [
    {
      name: 'talktally/ignores',
      ignores: ['**/dist/', '**/coverage/', '**/build/', '**/.expo/', '**/ios/', '**/android/'],
    },
    js.configs.recommended,
    ...tseslint.configs.strictTypeChecked,
    ...tseslint.configs.stylisticTypeChecked,
    {
      name: 'talktally/type-information',
      languageOptions: {
        parserOptions: { projectService: true, tsconfigRootDir },
      },
    },
    // Plain JavaScript files (configs, scripts) are not part of a tsconfig.
    { ...tseslint.configs.disableTypeChecked, files: jsFiles },
    // Must stay last: turns off rules that conflict with Prettier.
    prettier,
  ];
}

/**
 * Node.js code: root scripts and config files.
 * @param {Options} options
 * @returns {Config[]}
 */
export function node(options) {
  return [
    ...base(options),
    { name: 'talktally/node-globals', languageOptions: { globals: globals.node } },
  ];
}

/**
 * React for the browser (apps/web).
 * @param {Options} options
 * @returns {Config[]}
 */
export function web(options) {
  return [
    ...base(options),
    { ...reactHooks.configs.flat.recommended, files: jsxFiles },
    { ...jsxA11y.configs.recommended, files: jsxFiles },
    { name: 'talktally/browser-globals', languageOptions: { globals: globals.browser } },
  ];
}

/**
 * React Native (apps/mobile).
 * @param {Options} options
 * @returns {Config[]}
 */
export function mobile(options) {
  return [
    ...base(options),
    { ...reactHooks.configs.flat.recommended, files: jsxFiles },
    {
      // The plugin ships only legacy (eslintrc) configs, so its `all` rule set is wired by hand.
      name: 'talktally/react-native-a11y',
      files: jsxFiles,
      plugins: { 'react-native-a11y': reactNativeA11y },
      rules: reactNativeA11y.configs.all.rules,
    },
  ];
}

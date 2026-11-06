// Lints the files in the repository root only (scripts and config files).
// Each workspace has its own eslint.config.js.
import { node } from '@talktally/config/eslint';

export default [
  ...node({ tsconfigRootDir: import.meta.dirname }),
  // Deliberately broken code for scripts/check-architecture.test.mjs; not part of any tsconfig.
  { name: 'talktally/architecture-fixtures', ignores: ['scripts/fixtures/'] },
];

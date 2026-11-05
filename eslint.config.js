// Lints the files in the repository root only (scripts and config files).
// Each workspace has its own eslint.config.js.
import { node } from '@talktally/config/eslint';

export default node({ tsconfigRootDir: import.meta.dirname });

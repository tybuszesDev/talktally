// Shared Vitest settings. Plain JavaScript, so Node can load it without a TypeScript step.
// Use in a workspace: `export default defineConfig(baseConfig)` or `mergeConfig(baseConfig, {...})`.

/** @type {import('vitest/config').ViteUserConfig} */
const baseConfig = {
  test: {
    include: ['src/**/*.test.{ts,tsx}'],
    passWithNoTests: false,
    restoreMocks: true,
  },
};

export default baseConfig;

// Unused files, exports and dependencies, checked by knip (ADR-0017).
// Run with `pnpm check:unused`. Every exception below says why it is not a real finding.

/** @type {import('knip').KnipConfig} */
const config = {
  // Deliberately broken code for scripts/check-architecture.test.mjs.
  ignore: ['scripts/fixtures/**'],
  workspaces: {
    'apps/mobile': {
      // knip's Expo plugin infers these from app.json, but neither is needed yet: over-the-air
      // updates are not used, and `userInterfaceStyle` needs expo-system-ui only on Android (M7).
      ignoreDependencies: ['expo-updates', 'expo-system-ui'],
    },
  },
};

export default config;

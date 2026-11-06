// Architecture rules checked by dependency-cruiser (ADR-0001, ADR-0017).
// Run with `pnpm check:architecture`; scripts/check-architecture.test.mjs proves that every
// rule catches a violation.

/** Modules that tie code to a platform: React DOM, React Native, Expo and the AWS SDK. */
const PLATFORM_MODULES =
  '(^|/)(react-dom|react-native|expo|expo-[^/]+|@expo/[^/]+|@aws-sdk/[^/]+|aws-sdk)(/|$)';

/** @type {import('dependency-cruiser').IConfiguration} */
const config = {
  forbidden: [
    {
      name: 'packages-not-to-apps-or-services',
      comment: 'ADR-0001: shared packages never import apps or services.',
      severity: 'error',
      from: { path: '^packages/' },
      to: { path: '^(apps|services)/' },
    },
    {
      name: 'services-not-to-apps',
      comment: 'ADR-0001: backend services never import client apps.',
      severity: 'error',
      from: { path: '^services/' },
      to: { path: '^apps/' },
    },
    {
      name: 'apps-not-to-other-apps',
      comment: 'ADR-0001: an app never imports another app; shared code belongs in packages/.',
      severity: 'error',
      from: { path: '^apps/([^/]+)/' },
      to: { path: '^apps/', pathNot: '^apps/$1/' },
    },
    {
      name: 'platform-neutral-packages',
      comment:
        'ADR-0017: packages/domain and packages/client stay platform-neutral (no React DOM, ' +
        'React Native, Expo or AWS SDK). DOM globals are excluded by their tsconfig `lib`.',
      severity: 'error',
      from: { path: '^packages/(domain|client)/' },
      to: { path: PLATFORM_MODULES },
    },
    {
      name: 'no-circular',
      comment: 'ADR-0017: circular dependencies make modules impossible to understand alone.',
      severity: 'error',
      from: {},
      to: { circular: true },
    },
    {
      name: 'not-to-unresolvable',
      comment: 'An import that cannot be resolved is a typo or a missing dependency.',
      severity: 'error',
      from: {},
      to: { couldNotResolve: true },
    },
    {
      name: 'no-non-package-json',
      comment: 'Every imported package is declared in the package.json of the importing workspace.',
      severity: 'error',
      from: {},
      to: { dependencyTypes: ['npm-no-pkg', 'npm-unknown'] },
    },
    {
      name: 'not-to-dev-dep',
      comment:
        'Shipped source code does not import devDependencies; tests and type-only imports may.',
      severity: 'error',
      from: {
        path: '^(apps|packages|services)/[^/]+/src/',
        pathNot: '\\.(test|spec)\\.[cm]?[jt]sx?$',
      },
      to: { dependencyTypes: ['npm-dev'], dependencyTypesNot: ['type-only'] },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    // Build output of our workspaces only; a broader pattern would also hide imports of packages
    // whose entry point lives in node_modules/<package>/dist/.
    exclude: { path: '^(apps|packages|services)/[^/]+/(dist|coverage|build|ios|android|\\.expo)/' },
    tsPreCompilationDeps: true,
    enhancedResolveOptions: {
      exportsFields: ['exports'],
      conditionNames: ['import', 'require', 'node', 'react-native', 'default', 'types'],
      mainFields: ['module', 'main', 'types', 'typings'],
      extensions: ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.json'],
    },
  },
};

export default config;

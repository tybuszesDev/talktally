# ADR-0017: Code quality, security and cost checks in CI

- Status: Accepted
- Date: 2026-11-05

## Context

ADR-0011 defines tests. Tests do not catch architecture drift, dead code, vulnerable dependencies, accessibility problems or infrastructure changes that raise the monthly bill. The repository is public, so its security posture is visible to everyone. All of these checks must be automatic and must block merges, otherwise they decay.

## Decision

All checks below run in CI and are **required status checks** for merging to `main`.

### Code quality

- TypeScript `strict`, plus `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes`.
- typescript-eslint presets `strict-type-checked` and `stylistic-type-checked`; Prettier for formatting.
- **dependency-cruiser** enforces the rules of ADR-0001: `packages/*` never import `apps/*` or `services/*`; `packages/domain` and `packages/client` import no DOM, React Native or AWS SDK modules; no circular dependencies.
- **knip** reports unused files, exports and dependencies.

### Security

- **CodeQL** (JavaScript and TypeScript) on pull requests and weekly.
- **gitleaks** for secrets (also as a pre-commit hook), **trivy config** for Terraform (ADR-0003).
- **Renovate** for dependency updates; pnpm `minimumReleaseAge` so new package versions are installed only after a few days, and dependency install scripts run only for an explicit allowlist.
- **OpenSSF Scorecard** workflow with a badge in the README.
- **IAM Access Analyzer** (external access analyzer, free) in the AWS account.
- The threat model is in `docs/SECURITY-MODEL.md`. Pull requests that touch authentication, IAM or resolvers update it when needed.

### Cost

- **Infracost** comments the monthly cost difference on every pull request that changes `infra/`.

### Accessibility

- `eslint-plugin-jsx-a11y` for the web and an accessibility lint plugin for React Native.
- `@axe-core/playwright` in web end-to-end tests; serious and critical violations fail the run.

## Consequences

- Architecture rules from the ADRs are enforced by tools, not by memory.
- CI takes longer. Turborepo caching and affected-only runs keep it acceptable.
- Strict TypeScript and lint presets slow down the first features, but prevent whole classes of bugs.

## Alternatives considered

- **Manual review only:** does not scale and misses regressions.
- **Snyk or SonarCloud:** good dashboards; free tiers exist for open source, but CodeQL, Renovate and Scorecard cover the same needs inside GitHub.
- **eslint-plugin-boundaries instead of dependency-cruiser:** works inside ESLint, but dependency-cruiser also produces dependency graphs for the documentation.

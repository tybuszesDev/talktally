# CLAUDE.md

Instructions for Claude Code in this repository. Work status lives on the [project board](https://github.com/users/tybuszesDev/projects/1), not here.

## Project

**TalkTally** ("you talk, it tallies") is a voice-first tracker for personal projects. At the end of the day the owner dictates a summary in Polish; the system transcribes it, proposes structured changes (tasks, inventory, metrics), applies the confident ones and asks about the rest. Mobile (Expo) is the thin capture tool, web (Vite + React) is the command center, the backend is serverless AWS managed with Terraform. Single user plus a demo account; also a public portfolio project. Details: [docs/VISION.md](docs/VISION.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DOMAIN.md](docs/DOMAIN.md).

## Communication

- Talk to the owner in **Polish**.
- Write code, comments, docs, commit messages, issues and pull requests in **English**.
- The owner wants deliberate, phased work: propose a plan with a recommended option, ask at decision points, and record new decisions in an ADR before implementing them.

## Repository map

| Path | Content |
|---|---|
| `apps/web` | Vite + React SPA (`@talktally/web`) |
| `apps/mobile` | Expo SDK 58 app, development build (`@talktally/mobile`); `ios/` is generated and gitignored |
| `packages/config` | Shared tsconfig, ESLint, Prettier and Vitest presets |
| `packages/domain` | Platform-neutral domain code (no DOM, React Native or AWS SDK imports) |
| `services/`, `infra/terraform/` | Planned (ADR-0001, ADR-0003); created by the features that need them |
| `docs/` | Vision, architecture, domain, design, security model, roadmap, working agreement, ADRs |

## Commands

```sh
pnpm install                     # also installs the git hooks (prepare: lefthook install)
pnpm lint                        # ESLint in every workspace + root files + prettier --check
pnpm format                      # prettier --write (normally the pre-commit hook does this)
pnpm typecheck
pnpm test
pnpm build                       # Vite web build and Metro iOS bundle
pnpm check:versions              # fails if react, react-dom or typescript resolve to two versions
pnpm --filter @talktally/web dev # http://localhost:5173
pnpm --filter @talktally/mobile ios        # build and run on the iPhone 17 simulator
pnpm --filter @talktally/mobile ios:small  # iPhone 16e; ios:large = iPhone 17 Pro Max
pnpm --filter @talktally/mobile ios:clean  # regenerate apps/mobile/ios
```

## Workflow

Full rules: [docs/WORKING-AGREEMENT.md](docs/WORKING-AGREEMENT.md) (Definition of Ready, Definition of Done, checks by area).

1. **Before starting:** `git fetch --prune`, check open pull requests (`gh pr list`, `gh pr view N --json state,reviews,comments`), then `git switch main && git pull --ff-only`.
2. **One feature = one issue.** Find it by title `[F-xx]`; issue numbers differ from feature IDs after M0. At most one pull request waiting for review plus one feature in progress. After a merge, rebase the in-progress branch on `origin/main`.
3. **Branch:** `<type>/<issue>-<short-description>`, for example `feat/12-entry-upload`. Never commit to `main`.
4. **Board:** move the card to In progress when the branch exists and to In review when the pull request is open (`gh project item-edit`, project 1, field Status).
5. **Commits:** Conventional Commits, enforced by commitlint. Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`, `perf`. Scope is optional and must be a workspace folder name or `infra`. Every commit ends with the trailer `Assisted-by: Claude Opus 5.5` (the model actually used); never `Co-Authored-By` (ADR-0022).
6. **Pull request:** title = the planned commit title from the issue (it becomes the squash commit). The body follows `.github/pull_request_template.md`: `Closes #<issue>`, summary, checks run locally, the Definition of Done boxes (tick only what is true), exactly one manual-test box, and the area checks that apply. Required checks: `CI`, `PR title`, `PR checklist`; CodeRabbit threads must be resolved. No "Generated with Claude Code" footer.
7. **Only the owner merges** (squash merge in the GitHub web UI); nothing is merged automatically. Review comments arrive as pull request comments: read them with `gh` and push fixes to the same branch. Fill in the whole description when opening the pull request; review findings are enforced by the ruleset, not by a checkbox.
8. **Edits to code files need the owner's approval one by one** (`.claude/settings.json` asks for every code and config file, in every permission mode). Do not try to work around it. The only other source of code changes is CodeRabbit "Fix comments", which the owner triggers per finding (ADR-0023): run `git pull --ff-only` before continuing on a branch and review its commits like any diff.

## Code rules

- TypeScript `strict` with `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes`; ESLint presets from `packages/config/eslint` (typescript-eslint strict and stylistic type-checked, react-hooks, accessibility plugins).
- **Prettier runs only in the pre-commit hook and in CI.** Never add format-on-save settings or Claude Code formatting hooks. Markdown is not formatted by Prettier.
- Tests ship in the same pull request as the code (ADR-0011). A bug fix starts with a failing test. Unit tests never call real AWS services or Bedrock.
- No `TODO` without an issue number. Follow-up work becomes a new issue.
- Packages never import from apps or services. `packages/domain` stays platform-neutral.
- UI: every interactive element has a `testID` and an accessibility label; strings live in components or constant modules, not in business logic.
- Logs never contain transcripts, audio URLs, tokens or other user content (ADR-0015).

## Dependencies

- Shared versions live in the pnpm `catalog` in `pnpm-workspace.yaml`; workspaces reference them with `catalog:`.
- Use caret or tilde ranges, never exact pins of fresh releases. `minimumReleaseAge` (3 days) blocks new versions: never bypass it and never add `minimumReleaseAgeExclude`.
- pnpm fails on dependency build scripts nobody decided on: record each decision in `allowBuilds` (`pnpm approve-builds '!pkg'` denies).
- `react` is pinned to the exact version the Expo SDK's React Native requires. TypeScript stays on `~6.0` until typescript-eslint supports TypeScript 7.
- A new dependency needs a reason and the alternatives considered in the pull request, and a license compatible with MIT.

## Environment

- Keep the repository outside iCloud-synced folders (Desktop, Documents): iCloud adds extended attributes that break Xcode code signing.
- Homebrew tap formulas need the Xcode Command Line Tools, not only Xcode. Local tools: `gitleaks` (brew), Terraform (`hashicorp/tap/terraform`).
- The mobile app runs as a development build (`expo-dev-client`), not in Expo Go.

## Architecture decisions

Each ADR in one line, as amended. Read the ADR before changing anything in its area. Index: [docs/adr/README.md](docs/adr/README.md).

| ADR | Decision |
|---|---|
| [0001](docs/adr/0001-monorepo-pnpm-turborepo.md) | One pnpm + Turborepo monorepo, TypeScript (strict, ESM) on Node 24; packages never import apps or services. |
| [0002](docs/adr/0002-serverless-aws-and-cost-guardrails.md) | Only pay-per-request or free AWS services in `eu-central-1`; budget alarm at 10 USD/month; no NAT, EC2, RDS or VPC Lambdas. |
| [0003](docs/adr/0003-terraform-infrastructure-as-code.md) | All infrastructure in Terraform (>= 1.10) with S3 state, dev and prod roots, OIDC for CI, secrets in SSM Parameter Store. |
| [0004](docs/adr/0004-authentication-with-cognito.md) | Cognito user pool per environment, SRP sign-in with own screens via Amplify JS v6 (auth and api only), invite-only, demo account. |
| [0005](docs/adr/0005-graphql-api-with-appsync.md) | Schema-first AppSync GraphQL API with one routing Lambda resolver, generated types, owner-filtered subscriptions. |
| [0006](docs/adr/0006-dynamodb-single-table.md) | One on-demand DynamoDB table per environment, single-table design from DOMAIN access patterns, change sets in one transaction. |
| [0007](docs/adr/0007-voice-processing-pipeline.md) | Step Functions pipeline: presigned upload, S3 event, Transcribe `pl-PL`, Bedrock extraction, apply or review; audio archived, never auto-deleted. |
| [0008](docs/adr/0008-ai-proposes-changes-code-applies-them.md) | The model only proposes a Zod-validated change set; tested code applies it, auto-applies only confident safe operations, and supports undo. |
| [0009](docs/adr/0009-templates-over-fixed-domain-primitives.md) | Fixed domain primitives (work items, resources, metrics, plans, routines) configured by versioned templates; projects copy template seeds. |
| [0010](docs/adr/0010-client-applications.md) | Web: Vite SPA with TanStack Router/Query, Tailwind and shadcn/ui, Electron-ready; mobile: Expo Router development build, iOS first. |
| [0011](docs/adr/0011-testing-strategy-and-quality-gates.md) | Test levels from Vitest unit to Playwright and Appium; tests in the same commit; coverage 90% for domain, 70% elsewhere, only going up. |
| [0012](docs/adr/0012-git-workflow-and-ci-cd.md) | Trunk-based, squash merge, one Conventional Commit per pull request; lefthook locally; GitHub Actions with OIDC deploys to dev, approved prod. |
| [0013](docs/adr/0013-event-bus-for-domain-events-and-integrations.md) | One EventBridge bus per environment fed by DynamoDB Streams through Pipes; versioned domain events; integrations later, each with an ADR. |
| [0014](docs/adr/0014-mobile-distribution-and-device-testing.md) | EAS Build and Submit to TestFlight; Appium tests by `testID` on simulators nightly and on AWS Device Farm for releases. |
| [0015](docs/adr/0015-observability.md) | Powertools for Lambda (structured logs, traces, metrics), correlation IDs, SLOs, alarms by email, no user content in logs. |
| [0016](docs/adr/0016-release-management-and-work-traceability.md) | GitHub Issues, milestones and a project board; release-please creates one product version and changelog; `0.x` until the MVP. |
| [0017](docs/adr/0017-code-quality-security-and-cost-checks.md) | Required CI checks: strict lint, dependency-cruiser, knip, CodeQL, gitleaks, trivy, Renovate, Scorecard, Infracost, accessibility lint and axe. |
| [0018](docs/adr/0018-change-notifications-through-the-event-bus.md) | Clients learn about changes through Streams → Pipes → bus → AppSync `publishChange` signals and refetch; at-least-once delivery. |
| [0019](docs/adr/0019-feature-size-and-splitting.md) | Commit and push the branch daily; a feature longer than about two days is split into `F-xxa`, `F-xxb` pull requests as sub-issues. |
| [0020](docs/adr/0020-schema-evolution-and-backward-compatibility.md) | Breaking changes follow expand → migrate → contract; the GraphQL schema only grows within a release; items carry `schemaVersion`. |
| [0021](docs/adr/0021-code-review-for-ai-written-code.md) | Three review layers: CI tools, CodeRabbit, and the owner reading the full diff; only the owner merges; code edits approved one by one. |
| [0022](docs/adr/0022-ai-assistance-commit-trailer.md) | Commits name the model with `Assisted-by: <model>`, not `Co-Authored-By`; AI use is stated in the README. |
| [0023](docs/adr/0023-coderabbit-fixes-on-owner-request.md) | CodeRabbit "Fix comments" is on and triggered only by the owner per finding; other code-writing finishing touches off; no automatic merges. |

## Owner actions

Some features need something only the owner can do (accounts, DNS, recordings). The list is in [docs/ROADMAP.md](docs/ROADMAP.md#owner-actions).

- Check it before starting each feature. If the feature needs an action that is not done, say so and stop.
- Remind the owner early about upcoming actions, especially the long-running ones: real renovation dictations (3 before F-14, 20+ before F-45), the Apple Developer Program before F-24, Terraform, AWS CLI and an IAM Identity Center admin user before F-10.

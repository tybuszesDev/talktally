# Roadmap

- Status: Accepted 2026-11-05
- Related: [VISION](VISION.md), [ADR-0012](adr/0012-git-workflow-and-ci-cd.md) (git workflow), [ADR-0016](adr/0016-release-management-and-work-traceability.md) (issues and releases)

## How to read this

- A **milestone** is a GitHub milestone. It ends with a release.
- A **feature** is one GitHub issue. Usually it is one pull request and **one squash commit** on `main`; the title in the tables is the planned commit title. A feature that takes more than about two days is split into several pull requests (`F-44a`, `F-44b`, ...), each with its own commit ([ADR-0019](adr/0019-feature-size-and-splitting.md)).
- "Done when" is the short version. Each issue holds the full acceptance criteria.
- This file is the plan. Status and details live in the GitHub issues and the project board.
- Features are ordered: a feature may depend on any feature above it.
- Risky parts come early: authentication, real-time sync and the AI and transcription services are proven before the bulk of the features is built.

## Definition of done (every feature)

The full Definition of Ready, Definition of Done (feature and milestone) and the additional checks by area are in [WORKING-AGREEMENT.md](WORKING-AGREEMENT.md). In short: acceptance criteria met, tests and CI green, reviewed, deployed to `dev`, documented, issue closed by the merge.

## Overview

| Milestone | Goal | Release |
|---|---|---|
| M0 Foundation | Monorepo, tooling, CI, repository standards | — |
| M1 AWS foundation | Bootstrap, environments, infrastructure CI, risk spike | — |
| M2 Walking skeleton | Sign in on web and iPhone, one real query, live sync, deployed | first `0.x` |
| M3 Projects | Projects from templates, work items, inventory, metrics, engagement | `0.x` |
| M4 Voice | Dictation to reviewed and applied changes | `0.x` |
| M5 Daily plan | Plan of the day arranged by engagement, AI suggestions | `0.x` |
| M6 Release readiness | Privacy, account, demo, device tests, prod, README | **`1.0.0` = MVP** |
| M7–M11 | Post-MVP: Android, insights and email, templates, polish, desktop | `1.x` |

## Owner actions

Things only the owner can do. Check this list before starting each feature.

| Needed before | Action |
|---|---|
| F-05b | Install the Mend Renovate GitHub App on `tybuszesDev/talktally` only (not on all repositories) |
| F-06 (before merge) | Register the release GitHub App and create the `release` environment with its client ID and private key ([CONTRIBUTING](../CONTRIBUTING.md#github-app-and-release-environment)) |
| F-10 | Install Terraform and the AWS CLI (2.32.0 or later). Create an IAM administrator user with passkey MFA and sign in with `aws login`, so the root account is never used for daily work ([ADR-0026](adr/0026-admin-access-with-iam-user-and-aws-login.md)) |
| Before the free plan ends | Upgrade the AWS account to the paid plan by hand in the Billing console, so the account does not close ([ADR-0026](adr/0026-admin-access-with-iam-user-and-aws-login.md)) |
| F-12 | Add the four NS records for `talktally.tybu.com` in the Hostinger DNS zone editor |
| F-14 | Record 3 real renovation dictations (1–3 minutes each). Enable Bedrock model access for Anthropic models |
| F-24 | Active Apple Developer Program membership; free Expo account |
| F-26 | Free Sentry account |
| F-45 | At least 20 real dictations from normal working days. Tip: start recording daily with the iPhone Voice Memos app long before M4 |
| F-62 | Answer the App Store privacy questions in App Store Connect |

## M0 Foundation

| ID | Commit | Done when |
|---|---|---|
| F-01 | `chore: scaffold pnpm and Turborepo monorepo` | First workspaces (config, domain, web, mobile); pnpm catalog with one React and TypeScript version, checked by `pnpm check:versions`; Vite build and Metro iOS bundle both import `@talktally/domain`; `.easignore`; Node and pnpm pinned |
| F-02 | `chore: add lint, format and git hooks` | Prettier enforces the style; ESLint strict-type-checked with accessibility lint; lefthook formats and lints staged files, runs commitlint and gitleaks; formatting only in the hook and CI |
| F-03 | `docs: add CLAUDE.md, README, license and contribution guides` | CLAUDE.md, README skeleton, LICENSE (MIT), SECURITY.md, CONTRIBUTING.md with the local workflow, `.env.example`; `.claude/settings.json` requires approval of code edits |
| F-04 | `ci: add pull request pipeline` | Branch protection on `main`; issue and PR templates with the Definition of Done checklist enforced by CI; CodeRabbit installed; workflow runs lint, typecheck, test and build for affected workspaces |
| F-05 | `ci: add architecture, security and dependency checks` | dependency-cruiser rules, knip, CodeQL, OpenSSF Scorecard, Renovate, pnpm `minimumReleaseAge`; all are required checks |
| F-06 | `ci: add release-please` | Release pull request with `CHANGELOG.md` appears after a `feat` commit |

Also in M0, without a commit: GitHub Projects board, milestones M0–M6 and one issue per feature of this roadmap.

## M1 AWS foundation

| ID | Commit | Done when |
|---|---|---|
| F-10 | `feat(infra): add bootstrap stack with state, budgets and alerts` | State bucket with native locking; AWS Budgets (10 USD) and Cost Anomaly Detection email alerts; SNS alerts topic; applied locally and documented |
| F-11 | `feat(infra): add GitHub OIDC roles` | `plan` role trusted only by pull requests of this repository; `deploy` role trusted only by the `dev` and `prod` environments, which accept only `main` (and release tags for prod); no access keys exist ([ADR-0027](adr/0027-ci-access-to-aws-with-github-oidc-roles.md)) |
| F-12 | `feat(infra): add Route 53 zone for talktally.tybu.com` | Zone created; NS records added at Hostinger; `dig` resolves a test record |
| F-13 | `ci: add Terraform pipeline for the dev environment` | Root modules `envs/dev` and `envs/prod` with tagging; PRs show fmt, validate, tflint, trivy, `terraform test`, plan and Infracost comments; merge applies dev |
| F-14 | `docs: record Bedrock and Transcribe spike results` | Bedrock access to Claude Opus 5.5 confirmed from `eu-central-1`; account plan type checked; Transcribe `pl-PL` quality tested on 3 real renovation dictations; results and costs written down |

## M2 Walking skeleton

| ID | Commit | Done when |
|---|---|---|
| F-20 | `feat(auth): add Cognito user pool with invite-only sign-up` | User pool and two app clients in dev; self sign-up disabled; `pnpm invite <email>` creates a user |
| F-21 | `feat(api): add AppSync API with schema codegen and me query` | DynamoDB table, AppSync API, resolver Lambda with Powertools; `me` returns settings with defaults and `minimumClientVersion`; `schemaVersion` on items; codegen and schema-diff checks in CI; integration test with DynamoDB Local |
| F-22 | `feat(client): add shared auth and GraphQL client` | `packages/client` signs in with SRP, calls `me`, caches with TanStack Query; no DOM or React Native imports (dependency-cruiser) |
| F-23 | `feat(web): add web shell with sign-in, deployed to dev` | `packages/design-tokens`; Vite app with sign-in, sign-out and an account page; S3 + CloudFront on `dev.talktally.tybu.com`; Playwright smoke test with axe passes after deploy |
| F-24 | `feat(mobile): add iOS app shell with sign-in` | Expo app with sign-in and an account screen; EAS development and preview builds; first TestFlight internal build installed on the owner's iPhone; "Update required" screen below `minimumClientVersion` |
| F-25 | `feat(api): add live change notifications` | Streams → Pipes → bus → AppSync `publishChange` → `onChange` (ADR-0018); a settings change on the web appears on the phone within seconds; cross-user tests pass |
| F-26 | `feat(observability): add tracing, dashboard, alarms and Sentry` | Correlation ID end to end; X-Ray traces; dashboard and alarms in dev; Sentry receives a test error from web and mobile |

## M3 Projects

| ID | Commit | Done when |
|---|---|---|
| F-30 | `feat(domain): add domain primitives, units and decimals` | Zod schemas for all entities in DOMAIN.md; units with Polish aliases; exact decimal arithmetic; 90% coverage |
| F-31 | `feat(templates): add Blank and Renovation templates` | Template schema; both templates validate; instantiation creates seed resources, metrics and routines |
| F-32 | `feat(api): add projects with engagement` | Create from template, update, archive (with proportional redistribution), `setEngagement` enforcing 100%; ownership tests |
| F-33 | `feat(web): add projects list, template gallery and engagement settings` | Create a project from a template; set engagement shares; project dashboard skeleton |
| F-34 | `feat(api,web): add work items and shopping list` | CRUD and status changes; open items through the sparse index; purchases shown as a shopping list |
| F-35 | `feat(api,web): add resources with movement ledger` | Resources with units and low-stock threshold; consume, restock, adjust; history view |
| F-36 | `feat(api,web): add metrics with progress` | Metrics with `SUM` or `LATEST`, target and history; a monochrome progress chart |
| F-37 | `feat(mobile): add project switcher` | Active project selected on the phone; open items of the active project visible |

## M4 Voice

| ID | Commit | Done when |
|---|---|---|
| F-40 | `feat(api): add entry upload with quotas` | `createEntryUpload` returns a presigned POST limited by size and type; quotas and usage counters enforced; demo quotas configurable |
| F-41 | `feat(mobile): add recording with offline upload queue` | Record 16 kHz mono AAC; upload with progress; recordings made offline upload when the network returns |
| F-42 | `feat(pipeline): add transcription workflow` | S3 event starts Step Functions; Transcribe `pl-PL`; entry statuses published live; failures set `FAILED` with a reason; retry works; text entries skip transcription |
| F-43 | `feat(domain): add change set operations, apply and undo` | All operation schemas from ADR-0008; `applyChangeSet` and inverse operations are pure and tested; 100-item transaction limit handled |
| F-44 | `feat(pipeline): add AI extraction with review routing` | Context builder, prompt v1, structured outputs, validation, auto-apply above the threshold, pending operations with clarifications, one transaction per apply, AI metadata stored |
| F-45 | `test(pipeline): add extraction evaluation set` | At least 20 real Polish dictations with expected operations; `pnpm eval:extraction` reports precision, recall and cost; first report in `docs/evals/` |
| F-46 | `feat(mobile): add entry status and review screen` | Live status after recording; confirm, edit or reject pending operations; answer clarifications; undo |
| F-47 | `feat(web): add entry history, review inbox and text entries` | Entry list and detail with transcript and operations; inbox of pending reviews across projects; undo; text entry form |
| F-48 | `feat(infra): archive audio and support entry deletion` | Lifecycle rule to Glacier Deep Archive after 30 days; archived audio shown as archived; deleting an entry deletes its audio |

## M5 Daily plan

| ID | Commit | Done when |
|---|---|---|
| F-50 | `feat(domain): add daily plan allocation` | `capacityFor`, largest-remainder budgets, subtraction of fixed items, validation and trimming of suggestions; pure and tested |
| F-51 | `feat(api): add plan items and routines` | Plan CRUD with fractional positions; completing a linked item completes its work item; routines with idempotent materialization; `planAllocation` |
| F-52 | `feat(mobile): add today screen` | Today's plan with allocation line; check off and reorder; the microphone is the main action |
| F-53 | `feat(web): add day and week plan views with capacity slider` | Day and week views; allocation per project; capacity slider from 60 to 600 minutes in settings |
| F-54 | `feat(pipeline): add AI plan suggestions` | "Suggest my day"; suggestions after an evening entry and on the morning schedule; accept, edit, dismiss; nothing enters the plan without approval |
| F-55 | `feat(pipeline): support plan edits by voice` | Dictations such as "move tiling to tomorrow" produce `plan.*` operations; covered in the evaluation set |
| F-56 | `feat(events): add domain events and low-stock rule` | Domain events on the bus with archive; `ResourceLow` proposes a purchase item |

## M6 Release readiness (MVP)

| ID | Commit | Done when |
|---|---|---|
| F-60 | `feat(account): add settings` | Time zone, dictation language, auto-apply threshold on web and mobile |
| F-61 | `feat(account): add data export and account deletion` | JSON export through a time-limited link; in-app account deletion removes Cognito, DynamoDB and S3 data |
| F-62 | `feat(web): add privacy policy page` | `talktally.tybu.com/privacy`; App Store privacy answers documented |
| F-63 | `feat(demo): add demo account with daily reset` | Demo user with lower quotas and sample renovation data, reset every night |
| F-64 | `test(mobile): add device tests on simulators and AWS Device Farm` | Appium suite for critical flows; nightly simulator runs; Device Farm `ios-core` run on release tags with videos linked |
| F-65 | `feat(infra): add prod environment and release deployment` | prod on `talktally.tybu.com` and `api.talktally.tybu.com`; release-please release triggers deployment behind approval |
| F-66 | `docs: add runbooks and review security model` | Runbooks for pipeline failure, budget alarm, DynamoDB restore, audio restore; postmortem template; SECURITY-MODEL reviewed |
| F-67 | `docs: write README as project landing page` | Demo link, video, badges, C4 diagram, local setup in three commands, cost report, evaluation summary |

Merging the release pull request after M6 publishes **`1.0.0`**.

## Post-MVP

### M7 Android

- Google Play Console, internal testing track, `android-core` device pool, Android release.

### M8 Insights and email

- Capacity per weekday in settings.
- Weekly balance per project against the target shares.
- Weekly summary email (Amazon SES, EventBridge Scheduler), with unsubscribe.
- Actual durations recorded by voice.

### M9 Templates

- Learning, Software developer and Sales templates.
- Custom templates ("save project as template").
- Start a project by talking: AI drafts a template from the first dictation; the user edits it.
- Transcribe custom vocabulary per template.

### M10 Polish

- UI refinement from real use; dark theme.
- Storybook, Stryker mutation tests, Codecov.
- Feature flags with AWS AppConfig, web preview per pull request.
- k6 load test with results in the README, documentation site, SBOM and build attestations.

### M11 Desktop

- Electron app around the web app, with a tray icon and a global dictation shortcut.

### Backlog (not scheduled)

- Polish UI and i18n.
- Push notifications.
- Answering clarifications by voice.
- Live (streaming) transcription.
- External integrations (GitHub, calendars) through the event bus.
- Social login, shared projects.

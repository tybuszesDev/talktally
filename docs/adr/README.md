# Architecture Decision Records

Each significant decision is recorded as a short ADR. ADRs are immutable once accepted: to change a decision, write a new ADR that supersedes the old one.

## Status lifecycle

`Proposed` → `Accepted` → (`Superseded by ADR-XXXX` | `Deprecated`)

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-monorepo-pnpm-turborepo.md) | Monorepo with pnpm workspaces and Turborepo | Accepted |
| [0002](0002-serverless-aws-and-cost-guardrails.md) | Serverless on AWS with cost guardrails | Accepted |
| [0003](0003-terraform-infrastructure-as-code.md) | Terraform for all infrastructure | Accepted |
| [0004](0004-authentication-with-cognito.md) | Authentication with Amazon Cognito | Accepted |
| [0005](0005-graphql-api-with-appsync.md) | GraphQL API with AWS AppSync | Accepted, amended by 0018 |
| [0006](0006-dynamodb-single-table.md) | DynamoDB single-table data store | Accepted |
| [0007](0007-voice-processing-pipeline.md) | Voice processing pipeline | Accepted |
| [0008](0008-ai-proposes-changes-code-applies-them.md) | AI proposes change sets, deterministic code applies them | Accepted |
| [0009](0009-templates-over-fixed-domain-primitives.md) | Templates configure fixed domain primitives | Accepted |
| [0010](0010-client-applications.md) | Client applications: Vite SPA, Expo, Electron later | Accepted |
| [0011](0011-testing-strategy-and-quality-gates.md) | Testing strategy and quality gates | Accepted |
| [0012](0012-git-workflow-and-ci-cd.md) | Git workflow and CI/CD | Accepted, amended by 0019 |
| [0013](0013-event-bus-for-domain-events-and-integrations.md) | Event bus for domain events and future integrations | Accepted |
| [0014](0014-mobile-distribution-and-device-testing.md) | Mobile distribution and device testing | Accepted |
| [0015](0015-observability.md) | Observability | Accepted |
| [0016](0016-release-management-and-work-traceability.md) | Release management and work traceability | Accepted |
| [0017](0017-code-quality-security-and-cost-checks.md) | Code quality, security and cost checks in CI | Accepted |
| [0018](0018-change-notifications-through-the-event-bus.md) | Change notifications through the event bus | Accepted |
| [0019](0019-feature-size-and-splitting.md) | Feature size and splitting | Accepted |
| [0020](0020-schema-evolution-and-backward-compatibility.md) | Schema evolution and backward compatibility | Accepted |
| [0021](0021-code-review-for-ai-written-code.md) | Code review for AI-written code | Accepted, amended by 0022, 0023 and 0024 |
| [0022](0022-ai-assistance-commit-trailer.md) | AI assistance commit trailer | Accepted |
| [0023](0023-coderabbit-review-cadence-and-fixes.md) | CodeRabbit review cadence and owner-requested fixes | Accepted |
| [0024](0024-documentation-first-and-session-per-feature.md) | Documentation first and one session per feature | Accepted |

## Template

```markdown
# ADR-XXXX: Title

- Status: Proposed
- Date: YYYY-MM-DD

## Context
What forces are at play. What problem must be solved.

## Decision
What we do. Concrete and testable.

## Consequences
What becomes easier, what becomes harder, what we must watch.

## Alternatives considered
Each option with the reason it was not chosen.
```

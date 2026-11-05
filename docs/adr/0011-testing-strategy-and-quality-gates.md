# ADR-0011: Testing strategy and quality gates

- Status: Accepted
- Date: 2026-11-05

## Context

Every feature must be covered by tests, and CI must block a merge when they fail. The system mixes pure domain logic, Lambda handlers that call AWS, a GraphQL contract, two UIs, an AI step with non-deterministic output, and infrastructure code.

## Decision

### Test levels

| Level | Tools | Scope |
|---|---|---|
| Domain unit | Vitest | `packages/domain`, `packages/templates`: change set apply and undo, unit normalization, template instantiation, validation |
| Backend unit | Vitest, `aws-sdk-client-mock` | Resolver and pipeline handlers with mocked AWS clients |
| Backend integration | Vitest, DynamoDB Local (Docker) | Repository layer, key design, transactions and condition expressions |
| Contract | graphql-eslint, GraphQL Code Generator | Schema lint; generated types must be up to date |
| Authorization | Vitest | No resolver or subscription returns another user's data |
| AI extraction | Vitest with recorded responses; evaluation script | Parsing, validation and routing of proposals; quality measured with the evaluation set (ADR-0008) |
| Web | Vitest, React Testing Library, MSW | Components and screens with a mocked GraphQL API |
| Web end-to-end | Playwright | Smoke tests against the dev environment after deployment |
| Mobile | jest-expo, React Native Testing Library | Screens and hooks (Expo uses Jest, not Vitest) |
| Mobile end-to-end | Appium + WebdriverIO on iOS simulators and on real devices in AWS Device Farm | Critical flows on several screen sizes (ADR-0014) |
| Infrastructure | `terraform validate`, `tflint`, `trivy config`, `terraform test` | Module correctness and security rules |

### Rules

- A feature commit contains its tests. A bug fix starts with a failing test.
- Unit tests never call real AWS services or Bedrock.
- Coverage thresholds: 90% lines for `packages/domain`, 70% for other workspaces at the start. Thresholds can only go up.
- Tests follow Arrange-Act-Assert and describe behaviour in their names.
- Test data comes from builders in a shared test-utilities module, not from copied literals.

### Quality gates in CI (pull request)

`lint` → `typecheck` → `test` → `build` for affected workspaces, codegen check, Terraform checks and plan, secret scan. All must pass before merge.

## Consequences

- Domain logic, where most bugs would hurt the user, is the most tested part.
- Two test runners (Vitest and Jest) exist because of Expo. Shared test utilities must work with both.
- End-to-end tests run against a real environment, so they are slower and run after deployment, not on every push.

## Alternatives considered

- **Jest everywhere:** one runner, but slower and weaker ESM and Vite integration for the web and backend.
- **LocalStack for all AWS services:** realistic, but heavy for CI and partly paid features; DynamoDB Local plus mocks covers the important cases.
- **Live Bedrock calls in CI:** realistic, but costs money and makes tests flaky.

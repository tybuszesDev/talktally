# ADR-0005: GraphQL API with AWS AppSync

- Status: Accepted
- Date: 2026-11-05

## Context

Web and mobile must stay in sync: when a dictation finishes processing, the phone and the open web dashboard must both update without a refresh. Some updates come from the backend (the voice pipeline), not from a client mutation. The owner wants to practise GraphQL.

## Decision

**AWS AppSync GraphQL API**, one per environment.

- **Authorization modes:** Cognito user pools (default, for clients) and AWS IAM (for backend services only).
- **Schema-first:** `packages/graphql-schema/schema.graphql` is the contract. It uses AppSync scalars (`AWSDateTime`, `AWSJSON`) and directives (`@aws_cognito_user_pools`, `@aws_iam`, `@aws_subscribe`).
- **Code generation:** GraphQL Code Generator produces resolver types for `services/api` and typed documents for `packages/client`. CI fails if generated files are out of date.
- **Resolvers:** one Lambda resolver (Node.js 24, TypeScript) that routes by `typeName.fieldName` to handlers grouped by domain area. It is split into several Lambdas only when IAM permissions or scaling needs differ. APPSYNC_JS resolvers are allowed only for trivial key lookups and must have their own tests.
- **Subscriptions:** for example `onEntryUpdated(projectId)`, `onProjectChanged(projectId)`, `onPlanChanged(date)`.
  - Every subscription is filtered by the caller's identity. A user can never receive another user's events. This is covered by automated tests.
  - Backend-originated updates use IAM-only "publish" mutations (for example `publishEntryUpdate`) with a pass-through resolver. The pipeline calls them with SigV4 when its state changes, which triggers the subscription.
- **Client:** `packages/client` wraps Amplify's GraphQL client (it handles AppSync's real-time WebSocket protocol and authentication). TanStack Query caches query results; subscription events update the cache.
- **Errors:** domain errors return a typed `errorType` (for example `NotFound`, `ValidationFailed`, `QuotaExceeded`) that clients map to UI messages.

## Consequences

- Real-time sync without running our own WebSocket servers.
- Strong typing from schema to resolvers to UI.
- AppSync has its own GraphQL dialect and real-time protocol; standard tools such as Apollo Server or `graphql-ws` do not apply directly.
- Cost is per operation (about 4 USD per million queries and mutations, 2 USD per million real-time updates); negligible at this scale.
- A single resolver Lambda means one cold start path and simpler deployment, but coarse IAM permissions. Accepted for the MVP.

## Alternatives considered

- **API Gateway HTTP API + Lambda (REST):** simpler and cheaper, but real-time needs a separate WebSocket API, and it does not meet the goal of practising GraphQL.
- **AppSync Events (pub/sub only):** good for real-time, but no GraphQL query layer.
- **Apollo Server or GraphQL Yoga on Lambda:** standard GraphQL tooling, but subscriptions would need our own WebSocket infrastructure.
- **Direct APPSYNC_JS resolvers everywhere:** fewer Lambdas and no cold starts, but domain logic in a restricted JavaScript runtime is harder to test and reuse.

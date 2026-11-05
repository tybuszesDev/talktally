# ADR-0018: Change notifications through the event bus

- Status: Accepted
- Date: 2026-11-05
- Amends: [ADR-0005](0005-graphql-api-with-appsync.md) (how publish mutations are called)

## Context

ADR-0005 lets the voice pipeline call IAM-only publish mutations to trigger subscriptions. Changes made by users (completing a task on the web, editing the plan on the phone) also need to reach the other clients. Publishing from every resolver and every pipeline step would spread notification code everywhere and create dual writes: the data is saved, but the notification can fail.

## Decision

Every change reaches clients through one path, driven by committed data:

```
DynamoDB Streams → EventBridge Pipes → event bus → rule → AppSync mutation publishChange (IAM) → subscription onChange → client
```

- **Stream:** DynamoDB Streams with `NEW_AND_OLD_IMAGES`. Old images are also needed by domain events (for example `ResourceLow` detects crossing a threshold, ADR-0013).
- **Pipe:** filters out technical items (usage counters, idempotency records) and maps each change to a signal: `{ ownerId, projectId, entityType, entityId, changeKind }`.
- **Rule:** an EventBridge rule with **AWS AppSync as the target** calls `publishChange` through an IAM role. No custom Lambda is involved.
- **Signals, not data:** subscribers receive only the signal and refetch affected queries through TanStack Query. A missed or duplicated signal is harmless; clients also refetch after reconnecting.
- **Pipeline status changes** are writes to the entry item, so they use the same path. The pipeline no longer calls AppSync itself.
- **Reliability:** the rule has a retry policy and an SQS dead-letter queue, covered by the alarms in ADR-0015. Delivery is at least once, and ordering is not guaranteed.
- **Latency:** expected about 1–2 seconds from write to client; measured on the observability dashboard.

## Consequences

- One mechanism for all changes, defined in Terraform instead of application code.
- The same stream and bus serve client notifications and domain events (ADR-0013).
- A small extra delay compared with publishing directly from the resolver.
- The stream keeps records for 24 hours; a long outage of the Pipe loses signals, which is acceptable because clients refetch on reconnect.

## Alternatives considered

- **Publish from resolvers and pipeline steps (ADR-0005 as written):** notification code in many places and dual-write failures.
- **Lambda consumer of the stream that calls AppSync:** works, but adds code, cold starts and permissions that EventBridge already provides.
- **AppSync Events API:** a separate pub/sub API next to the GraphQL API; more surface for the same result.

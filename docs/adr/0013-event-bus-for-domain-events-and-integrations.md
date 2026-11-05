# ADR-0013: Event bus for domain events and future integrations

- Status: Accepted
- Date: 2026-11-05

## Context

Several reactions should follow domain changes without coupling the code that makes the change: suggest a plan after an evening summary, add a purchase item when a resource runs low, and later send data to or receive data from external services (GitHub, calendars). No external integration is connected in the MVP, but the architecture must be ready for them.

## Decision

- **One custom EventBridge bus per environment.**
- **Producer:** DynamoDB Streams → **EventBridge Pipes** (filter and transform) → bus. Domain events are derived from committed data, so there are no dual writes and no lost events when a Lambda fails after writing.
- **Event contract:** each event has `source = talktally.<context>`, a `detail-type` such as `ChangeSetApplied`, and a versioned `detail` defined by a Zod schema in `packages/domain`.
- **Initial events:** `EntryProcessed`, `ChangeSetApplied`, `WorkItemCompleted`, `ResourceLow`, `PlanSuggested`.
- **Initial consumers (MVP):**
  - `ResourceLow` → propose a purchase work item.
  - `EntryProcessed` (evening entries) → generate plan suggestions for the next day.
  - **EventBridge Scheduler** in the morning → generate plan suggestions if none exist for today.
- **Archive** on the bus (short retention) so events can be replayed during development.
- **Prepared for integrations, not connected:** inbound events will arrive through a Lambda function URL or API destination and be published to the same bus; outbound integrations will be rules with API destinations. Each integration gets its own ADR.

## Consequences

- New reactions are added as rules and consumers, without changing the producers.
- Event schemas become a contract that must be versioned and tested.
- Debugging spans more services; X-Ray tracing and the archive help.

## Alternatives considered

- **Direct Lambda-to-Lambda calls:** simpler at first, but tight coupling and lost events on failures.
- **Amazon SNS + SQS fan-out:** works, but filtering, archive, replay and scheduling are weaker than EventBridge.
- **Publishing events from resolver code:** risk of a successful write with a failed publish (dual write problem).

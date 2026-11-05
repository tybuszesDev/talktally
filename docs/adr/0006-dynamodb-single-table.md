# ADR-0006: DynamoDB single-table data store

- Status: Accepted
- Date: 2026-11-05

## Context

Data is owned by one user, read mostly by project and by date, and written in small atomic batches (one change set from one dictation). Costs must be close to zero at idle. Relational databases on AWS either bill per hour or need a VPC, which brings NAT or VPC endpoint costs.

## Decision

**Amazon DynamoDB, one table per environment, on-demand capacity.**

- **Single-table design.** The access patterns are listed in `docs/DOMAIN.md` before the key design is fixed. Tentative shape:
  - `PK = USER#<sub>`: the user's projects, plans and settings.
  - `PK = PROJECT#<id>`: the project's work items, resources, movements, metrics, entries and change sets.
  - One or two global secondary indexes for queries by status and date.
- **Ownership:** every item stores `ownerId`. Every resolver checks that the requested project belongs to the caller before reading or writing.
- **Atomic change sets:** one change set is applied with `TransactWriteItems` (up to 100 items) with condition expressions. Items carry a `version` attribute for optimistic locking.
- **Resource quantity:** stored as a ledger of movements plus a cached current quantity updated in the same transaction.
- **TTL** for temporary items (idempotency keys, upload sessions).
- **DynamoDB Streams** enabled; they feed the event bus (ADR-0013).
- **Point-in-time recovery** enabled in prod.
- **Local testing** with DynamoDB Local in Docker.

## Consequences

- Near-zero cost at idle, no connection management in Lambda.
- Access patterns must be designed up front. A new kind of query can require a new index or a data migration.
- Ad hoc reporting is harder than with SQL. Accepted; analytics are out of the MVP.

## Alternatives considered

- **Aurora Serverless v2 (PostgreSQL):** relational model fits well and it can scale to zero, but resuming takes seconds and it requires a VPC.
- **RDS free tier:** limited to 12 months on older accounts, then billed per hour; also needs a VPC.
- **External databases (Neon, Supabase, PlanetScale):** good products, but outside AWS.
- **One table per entity:** easier to read for newcomers, but more resources to manage and no cross-entity transactions per project partition.

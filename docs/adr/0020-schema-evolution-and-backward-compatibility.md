# ADR-0020: Schema evolution and backward compatibility

- Status: Accepted
- Date: 2026-11-05

## Context

Several versions of the system are alive at the same time:

- Mobile builds from TestFlight and later the App Store stay installed for weeks.
- Web tabs stay open with old JavaScript.
- DynamoDB holds items written months ago; the event bus archive holds old events.

Changing the shape of an API field or a stored item in one step breaks old clients or leaves data that new code cannot read. Integrity of user data has priority over development speed.

## Decision

**Every breaking change follows expand → migrate → contract.**

1. **Expand:** add the new field or item shape next to the old one. Writers write the new shape (and the old one, if old readers still exist). Readers accept both.
2. **Migrate:** move existing data with a migration script and update the clients.
3. **Contract:** remove the old shape only when no supported client uses it and all data is migrated.

**GraphQL API**

- Within one release, the schema only grows: new types, new optional fields, new arguments with defaults.
- The type or meaning of an existing field never changes. A new meaning gets a new field.
- Removal: mark the field `@deprecated(reason: ...)` first; remove it only after `minimumClientVersion` excludes every build that uses it.
- CI compares the schema with `main` (GraphQL Inspector) and fails on breaking changes unless the pull request carries the label `breaking-approved`.

**Client versions**

- `me` returns `minimumClientVersion`, stored in Parameter Store per environment.
- The mobile app (and later the desktop app) shows a blocking "Update required" screen when it is older.
- The web app reloads its configuration when the tab regains focus, so old tabs pick up a new version.

**DynamoDB items**

- Every item carries `schemaVersion` (integer).
- The repository layer parses each version with its Zod schema and upgrades it in memory to the latest version, so old items stay readable.
- Migrations live in `services/migrations`. They are idempotent, can resume after a failure, and have a dry-run mode.
- Before a prod migration, an on-demand backup is taken in addition to point-in-time recovery.

**Events and change sets**

- Domain events (ADR-0013) and change set operation payloads (ADR-0008) carry a version. Consumers accept the current and the previous version.

## Consequences

- Old phones, open tabs and old data keep working during every change, and a deployment can be rolled back without breaking stored data.
- A breaking change takes several pull requests instead of one.
- `schemaVersion` and version-aware parsing add a little code to every repository.

## Alternatives considered

- **Versioned API endpoints (`/v2`):** heavy for AppSync, which serves one schema per API.
- **Big-bang migrations with downtime:** break offline mobile clients and make rollbacks unsafe.
- **No versioning rules:** fastest at first, but the first incompatible change can corrupt user data.

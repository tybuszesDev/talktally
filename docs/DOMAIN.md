# Domain model

- Status: Accepted 2026-11-05. The section [Daily plan allocation](#daily-plan-allocation) was added after the review and is still a draft.
- Related: [ADR-0006](adr/0006-dynamodb-single-table.md) (data store), [ADR-0008](adr/0008-ai-proposes-changes-code-applies-them.md) (change sets), [ADR-0009](adr/0009-templates-over-fixed-domain-primitives.md) (templates)

## Conventions

- **IDs** are ULIDs: unique, URL-safe and sortable by creation time.
- **Timestamps** are UTC ISO 8601 strings (`2026-11-05T18:42:00Z`).
- **Calendar dates** (plan dates, "when it happened") are local dates `YYYY-MM-DD` in the user's time zone (default `Europe/Warsaw`).
- **Quantities** are exact decimals. DynamoDB stores numbers as exact decimals; the repository reads them without converting to JavaScript floats, and `packages/domain` calculates with a decimal library.
- **Units** come from a fixed list in `packages/domain`: `piece`, `bag`, `pack`, `tube`, `roll`, `m`, `m2`, `m3`, `l`, `kg`, `hour`. Each unit has Polish and English aliases for extraction ("worek" → `bag`, "metr kwadratowy" / "m²" → `m2`, "kartusz" → `tube`). There is no conversion between units in the MVP; a mismatch becomes a clarification.
- **No hard deletes** in normal use: projects are archived, work items are cancelled. Hard deletion happens only for entry deletion and account deletion.
- **Optimistic locking:** mutable items carry `version`; every update has a condition on it.

## Entities

### User settings

| Field | Type | Notes |
|---|---|---|
| `userId` | string | Cognito `sub` |
| `timeZone` | string | IANA name, default `Europe/Warsaw` |
| `dictationLanguage` | string | default `pl-PL` |
| `autoApplyThreshold` | decimal | default `0.85` |
| `dailyCapacityMinutes` | map | minutes available for planned work, per weekday; default 240 for every day |
| `activeProjectId` | ID? | project preselected on mobile |
| `quotas` | object | see [Quotas](#quotas) |

### Project

| Field | Type | Notes |
|---|---|---|
| `id`, `ownerId` | ID | |
| `name` | string | |
| `status` | `ACTIVE` \| `ARCHIVED` | |
| `engagementPercent` | int | share of the daily capacity, 0–100; active projects sum to 100 |
| `templateId`, `templateVersion` | string, int | snapshot of the template used |
| `modules` | list | enabled modules: `workItems`, `resources`, `metrics`, `routines` |
| `attributeDefinitions` | list | custom fields from the template |
| `vocabulary` | list | extraction hints and Transcribe terms, copied from the template |
| `createdAt`, `updatedAt`, `version` | | |

### Work item

| Field | Type | Notes |
|---|---|---|
| `id`, `projectId` | ID | |
| `kind` | `TASK` \| `ISSUE` \| `PURCHASE` | purchases form the shopping list |
| `title`, `notes` | string | |
| `status` | `OPEN` \| `DONE` \| `CANCELLED` | |
| `dueOn` | date? | |
| `resourceId`, `quantity` | ID?, decimal? | for purchases: what and how much to buy |
| `attributes` | map | validated against `attributeDefinitions` |
| `origin` | `USER` \| `AI` | with `entryId` when created from a dictation |
| `completedAt` | timestamp? | |

### Resource and movement

| Resource field | Type | Notes |
|---|---|---|
| `id`, `projectId` | ID | |
| `name`, `aliases` | string, list | aliases help extraction ("klej Atlas", "klej") |
| `unit` | unit | |
| `quantity` | decimal | cached current value, updated with each movement |
| `lowStockThreshold` | decimal? | crossing it emits `ResourceLow` |

| Movement field | Type | Notes |
|---|---|---|
| `id`, `resourceId` | ID | |
| `type` | `CONSUME` \| `RESTOCK` \| `ADJUST` | |
| `delta`, `quantityAfter` | decimal | |
| `occurredOn` | date | |
| `entryId`, `operationId` | ID? | link to the change that caused it |

### Metric and metric entry

| Metric field | Type | Notes |
|---|---|---|
| `id`, `projectId` | ID | |
| `name`, `aliases`, `unit` | | for example "Tiles laid", `m2` |
| `aggregation` | `SUM` \| `LATEST` | sum of progress, or the latest reading |
| `target` | decimal? | for example 40 m² |
| `value` | decimal | cached aggregated value |

| Metric entry field | Type | Notes |
|---|---|---|
| `id`, `metricId` | ID | |
| `value`, `occurredOn` | decimal, date | |
| `entryId`, `operationId` | ID? | |

### Entry and change set

An entry is one dictation or text note. Its change set is stored **inside the entry item**, because the two always change together.

| Entry field | Type | Notes |
|---|---|---|
| `id`, `projectId`, `ownerId` | ID | |
| `source` | `VOICE` \| `TEXT` | |
| `status` | `UPLOADING` \| `TRANSCRIBING` \| `EXTRACTING` \| `NEEDS_REVIEW` \| `APPLIED` \| `FAILED` | |
| `occurredOn` | date | the day the entry describes; default today |
| `audio` | object? | S3 key, duration, `AVAILABLE` \| `ARCHIVED` |
| `transcript` | string? | |
| `failure` | object? | step and reason |
| `changeSet` | object? | see below |

| Change set field | Type | Notes |
|---|---|---|
| `operations` | list | see below |
| `model` | object | model ID, prompt version, tokens, latency, estimated cost (ADR-0015) |
| `createdAt` | timestamp | |

| Operation field | Type | Notes |
|---|---|---|
| `id` | ID | |
| `type` | string | `task.complete`, `resource.consume`, `plan.add`, ... (ADR-0008) |
| `payload` | object | validated by the Zod schema of its type |
| `confidence`, `evidence` | decimal, string | |
| `clarification` | object? | question and suggested answers |
| `state` | `PENDING` \| `AUTO_APPLIED` \| `CONFIRMED` \| `EDITED` \| `REJECTED` \| `UNDONE` | |
| `inverse` | object? | stored when applied, used by undo |

Entry status rules:

- `NEEDS_REVIEW` while at least one operation is `PENDING`; `APPLIED` when none are.
- A failed entry can be retried. Extraction can be repeated only while no operation of the entry has been applied.

### Daily plan item

The plan belongs to the **user**, not to a project: one plan per day across all projects.

| Field | Type | Notes |
|---|---|---|
| `id`, `ownerId` | ID | |
| `date` | date | |
| `title` | string | |
| `projectId`, `workItemId` | ID? | link to a project and optionally a work item |
| `position` | string | fractional index for ordering without rewriting other items |
| `estimateMinutes` | int? | expected duration; suggested by AI, editable |
| `source` | `MANUAL` \| `ROUTINE` \| `AI` \| `VOICE` | |
| `status` | `SUGGESTED` \| `PLANNED` \| `DONE` \| `SKIPPED` | `SUGGESTED` items wait for acceptance |
| `suggestionReason` | string? | why the AI suggested it |
| `routineId` | ID? | |

Completing a plan item that links a work item also completes the work item, in one transaction.

### Routine

| Field | Type | Notes |
|---|---|---|
| `id`, `projectId` | ID | |
| `title` | string | |
| `schedule` | object | `DAILY`, `WEEKDAYS`, or `WEEKLY` with a list of weekdays |
| `active` | boolean | |

Routine plan items are created for a date the first time that date's plan is read or generated. Creation is idempotent per routine and date.

### Daily plan allocation

The user divides their attention between projects with **engagement percentages**, for example Renovation 60%, Learning English 30%, Raking leaves 10%. The daily plan is arranged according to these shares.

**Rules**

- Engagement of all active projects sums to 100%. A new project starts at 0% and is not planned until the user gives it a share.
- When a project is archived, its share is redistributed to the other active projects in proportion to their current shares. The user can adjust it afterwards.
- A project at 0% is paused: it keeps its data but receives no plan suggestions.

**Algorithm** (the same principle as ADR-0008: code decides the numbers, AI chooses the content)

1. **Budget per project (code).** Capacity of the day × engagement, rounded to 5 minutes with the largest-remainder method, so the budgets add up exactly to the capacity.
   - Example: 240 min at 60 / 30 / 10% gives 145, 70 and 25 minutes.
2. **Fixed items first (code).** Items already in the plan (manual, voice, accepted suggestions) and routines due that day are subtracted from their project's budget. Items without a project are shown separately and do not use any budget.
3. **Filling the rest (AI).** For each project with remaining budget, the model picks open work items and estimates their duration. Priorities: overdue, due soon, unfinished yesterday, open issues; purchases are grouped into one item. If a project has no open work, the model may propose a new item (for example "30 min vocabulary practice"). Each suggestion has a short reason.
4. **Validation (code).** Suggestions may reference only open work items of that project. Estimates must be between 5 and 240 minutes. If a project's suggestions exceed its remaining budget by more than 10%, the lowest-priority ones are dropped.
5. **Approval (user).** Suggestions appear as `SUGGESTED`. The user accepts, edits or dismisses them. Nothing enters the plan without the user's approval.

**Presentation**

The top of the plan shows one quiet line per project: planned minutes against the budget, for example "Renovation 2 h 25 min of 2 h 25 min · English 40 min of 1 h 10 min · Leaves 0 of 25 min". When the plan is over capacity, the total shows "30 min over", without colour or warnings.

**Post-MVP:** a weekly balance (time of completed items per project against the target shares), and recording actual durations by voice ("English took me an hour").

### Usage

Per user per day: dictation seconds, entries, AI calls. Used for quota checks; expires after 90 days.

### Template

Templates are code in `packages/templates` (ADR-0009), not database items. A project keeps a copy of what it needs.

## Quotas

| Quota | Default | Demo account |
|---|---|---|
| Maximum audio length per entry | 10 min | 2 min |
| Dictation minutes per day | 30 | 5 |
| AI calls per day (extraction + plan suggestions) | 50 | 10 |

## Access patterns

| ID | Pattern | Used by |
|---|---|---|
| AP1 | List my projects | web, mobile |
| AP2 | Get a project with its open work items, resources, metrics and routines | web dashboard, extraction context |
| AP3 | List open work items of a project, optionally by kind (shopping list = `PURCHASE`) | web, mobile, extraction |
| AP4 | List all work items of a project, newest first, paged | web |
| AP5 | Movement history of one resource, newest first | web |
| AP6 | Entry history of one metric, by date | web charts |
| AP7 | Entries of a project, newest first, paged | web, mobile, extraction context |
| AP8 | Get one entry with its change set | web, mobile, pipeline |
| AP9 | Entries waiting for review across all my projects | mobile badge, web inbox |
| AP10 | Plan items for one date | mobile today, web |
| AP11 | Plan items for a date range | web week view |
| AP12 | Active routines of my projects | plan materialization |
| AP13 | Usage of today | quota checks |
| AP14 | Settings | all clients |

## DynamoDB key design

One table `talktally-<env>-main` with `PK`, `SK` and one sparse global secondary index `GSI1` (`GSI1PK`, `GSI1SK`, projection ALL).

| Item | PK | SK | GSI1PK | GSI1SK |
|---|---|---|---|---|
| Settings | `USER#<sub>` | `SETTINGS` | | |
| Usage | `USER#<sub>` | `USAGE#<date>` | | |
| Project | `USER#<sub>` | `PROJECT#<projectId>` | | |
| Plan item | `USER#<sub>` | `PLAN#<date>#<itemId>` | | |
| Work item | `PROJECT#<projectId>` | `WI#<itemId>` | `PROJECT#<projectId>#OPEN` (only while `OPEN`) | `<kind>#<itemId>` |
| Resource | `PROJECT#<projectId>` | `RES#<resourceId>` | | |
| Movement | `PROJECT#<projectId>` | `MOV#<resourceId>#<movementId>` | | |
| Metric | `PROJECT#<projectId>` | `MET#<metricId>` | | |
| Metric entry | `PROJECT#<projectId>` | `METE#<metricId>#<date>#<entryId>` | | |
| Routine | `PROJECT#<projectId>` | `ROUT#<routineId>` | | |
| Entry | `PROJECT#<projectId>` | `ENTRY#<entryId>` | `USER#<sub>#REVIEW` (only while `NEEDS_REVIEW`) | `<entryId>` |
| Idempotency record | `IDEMP#<key>` | `IDEMP` | | |

How each access pattern is served:

| ID | Operation |
|---|---|
| AP1 | Query `PK = USER#<sub>`, `SK begins_with PROJECT#` |
| AP2 | GetItem project (also the ownership check), then Query `PK = PROJECT#<id>` for `RES#`, `MET#`, `ROUT#`, plus AP3 |
| AP3 | Query `GSI1PK = PROJECT#<id>#OPEN`, optionally `GSI1SK begins_with <kind>#` |
| AP4 | Query `PK = PROJECT#<id>`, `SK begins_with WI#`, descending, paged |
| AP5 | Query `SK begins_with MOV#<resourceId>#`, descending |
| AP6 | Query `SK begins_with METE#<metricId>#`, optionally `between` two dates |
| AP7 | Query `SK begins_with ENTRY#`, descending, paged |
| AP8 | GetItem `ENTRY#<entryId>` |
| AP9 | Query `GSI1PK = USER#<sub>#REVIEW` |
| AP10 | Query `PK = USER#<sub>`, `SK begins_with PLAN#<date>#`; sorted by `position` in code |
| AP11 | Query `SK between PLAN#<from># and PLAN#<to>#~` |
| AP12 | AP1, then Query `ROUT#` per active project (a user has few projects) |
| AP13 | GetItem `USAGE#<date>` |
| AP14 | GetItem `SETTINGS` |

Notes:

- **Ownership is in the key.** A project item exists only under its owner's `USER#<sub>` partition. Every resolver that receives a `projectId` first reads `USER#<caller>/PROJECT#<projectId>`; if it does not exist, the request fails with `NotFound`. Child items also store `ownerId` for defence in depth.
- **Sparse indexes** keep "open work items" and "entries waiting for review" cheap: the GSI attributes exist only in those states and are removed on transition.
- **Applying a change set** is one `TransactWriteItems` call: the entry (operation states), and the affected work items, resources, movements, metrics, metric entries and plan items. The domain function checks the 100-item limit before writing; a larger change set is split into several transactions.
- Usage and idempotency items use DynamoDB TTL.

## Change notification flow

Accepted as [ADR-0018](adr/0018-change-notifications-through-the-event-bus.md).

All writes, from users and from the pipeline, notify clients through one path:

```
DynamoDB Streams → EventBridge Pipes → event bus → rule → AppSync publish mutation (IAM) → subscription → client
```

- EventBridge can call an AppSync mutation as a rule target, so no custom Lambda is needed for notifications.
- Subscription payloads are **signals**, not data: `{ ownerId, projectId, entityType, entityId, changeKind }`. Clients refetch the affected queries through TanStack Query. This keeps the subscription small, avoids leaking fields, and makes missed messages harmless: refetching on reconnect is enough.
- This amends ADR-0005, where the pipeline itself called the publish mutations.

## GraphQL schema draft

The shape of the API, not the final schema. Pagination uses `first` / `after` cursors. `Operation.payload` is `AWSJSON`; clients validate it with the same Zod schemas as the server (`packages/domain`), which avoids a large GraphQL union of payload types.

```graphql
type Query {
  me: Me!
  templates: [Template!]!
  projects(status: ProjectStatus): [Project!]!
  project(id: ID!): Project
  entry(projectId: ID!, id: ID!): Entry
  pendingReviews: [Entry!]!
  plan(date: AWSDate!): [PlanItem!]!
  planRange(from: AWSDate!, to: AWSDate!): [PlanItem!]!
  planAllocation(date: AWSDate!): [ProjectAllocation!]!   # budget and planned minutes per project
}

type Project {
  id: ID!
  name: String!
  status: ProjectStatus!
  engagementPercent: Int!
  template: TemplateRef!
  openWorkItems(kind: WorkItemKind): [WorkItem!]!
  workItems(first: Int, after: String): WorkItemConnection!
  resources: [Resource!]!
  metrics: [Metric!]!
  routines: [Routine!]!
  entries(first: Int, after: String): EntryConnection!
}

type Mutation {
  createProject(input: CreateProjectInput!): Project!
  updateProject(input: UpdateProjectInput!): Project!
  archiveProject(id: ID!): Project!
  setEngagement(input: [EngagementInput!]!): [Project!]!          # all shares at once; must sum to 100

  createWorkItem(input: CreateWorkItemInput!): WorkItem!
  updateWorkItem(input: UpdateWorkItemInput!): WorkItem!
  setWorkItemStatus(projectId: ID!, id: ID!, status: WorkItemStatus!): WorkItem!

  createResource(input: CreateResourceInput!): Resource!
  updateResource(input: UpdateResourceInput!): Resource!
  recordMovement(input: RecordMovementInput!): Resource!

  createMetric(input: CreateMetricInput!): Metric!
  updateMetric(input: UpdateMetricInput!): Metric!
  recordMetricEntry(input: RecordMetricEntryInput!): Metric!

  createRoutine(input: CreateRoutineInput!): Routine!
  updateRoutine(input: UpdateRoutineInput!): Routine!

  createEntryUpload(input: CreateEntryUploadInput!): EntryUpload!   # entry + presigned POST
  createTextEntry(input: CreateTextEntryInput!): Entry!
  retryEntry(projectId: ID!, id: ID!): Entry!
  reviewOperation(input: ReviewOperationInput!): Entry!            # confirm, edit or reject
  undoOperation(projectId: ID!, entryId: ID!, operationId: ID!): Entry!
  deleteEntry(projectId: ID!, id: ID!): Boolean!

  addPlanItem(input: AddPlanItemInput!): PlanItem!
  updatePlanItem(input: UpdatePlanItemInput!): PlanItem!            # title, date, position, status
  requestPlanSuggestions(date: AWSDate!): Boolean!                 # "suggest my day"; results arrive as signals
  acceptSuggestion(id: ID!, date: AWSDate!): PlanItem!
  dismissSuggestion(id: ID!, date: AWSDate!): Boolean!

  updateSettings(input: UpdateSettingsInput!): Me!
  requestDataExport: DataExport!
  deleteAccount: Boolean!

  # Backend only (IAM authorization)
  publishChange(input: ChangeSignalInput!): ChangeSignal! @aws_iam
}

type Subscription {
  onChange(ownerId: ID!): ChangeSignal
    @aws_subscribe(mutations: ["publishChange"])
}

type ChangeSignal @aws_iam @aws_cognito_user_pools {
  ownerId: ID!
  projectId: ID
  entityType: EntityType!   # PROJECT, WORK_ITEM, RESOURCE, METRIC, ENTRY, PLAN_ITEM, ROUTINE
  entityId: ID!
  changeKind: ChangeKind!   # CREATED, UPDATED, DELETED
}

type Operation {
  id: ID!
  type: String!
  payload: AWSJSON!
  confidence: Float!
  evidence: String!
  clarification: Clarification
  state: OperationState!
}
```

The subscription resolver rejects the request unless `ownerId` equals the caller's `sub`. Automated tests check that a user never receives another user's signals.

## Example: the renovation dictation

Input (Polish): "Zużyłem 4 kleje Atlas, położyłem 3 m² płytek, naprawiłem wczorajszy problem z hydrauliką, muszę kupić silikon sanitarny."

Context sent to the model: resources `Tile adhesive Atlas Plus (bag)` and `Tile adhesive Atlas Geoflex (bag)`, metric `Tiles laid (m2)`, open issue `Plumbing leak under the sink`.

Proposal:

| Operation | Payload | Confidence | State |
|---|---|---|---|
| `resource.consume` | 4 `bag`, resource undecided | 0.55 | `PENDING`, clarification: "Atlas Plus or Atlas Geoflex?" |
| `metric.record` | Tiles laid +3 `m2` | 0.95 | `AUTO_APPLIED` |
| `task.complete` | "Plumbing leak under the sink" | 0.90 | `AUTO_APPLIED` |
| `task.create` | `PURCHASE` "Sanitary silicone", 1 `tube` | 0.92 | `AUTO_APPLIED` |

Entry status: `NEEDS_REVIEW` until the user answers the clarification.

## Review decisions (2026-11-05)

1. One daily plan per user across all projects, arranged by engagement percentages (see [Daily plan allocation](#daily-plan-allocation)).
2. Work item statuses `OPEN`, `DONE` and `CANCELLED` are enough for the MVP.
3. The change notification flow is accepted as ADR-0018.
4. The quota defaults are accepted.

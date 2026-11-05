# ADR-0008: AI proposes change sets, deterministic code applies them

- Status: Accepted
- Date: 2026-11-05

## Context

A transcript such as "I used 4 bags of Atlas adhesive, laid 3 m² of tiles, fixed yesterday's plumbing problem, I need to buy sanitary silicone" must become precise updates to existing records. Language models are good at understanding such text but can be wrong, ambiguous or inconsistent. Wrong writes to inventory or task status damage the user's trust. When the system is not sure, it must ask.

## Decision

The model **never writes to the database**. It returns a **change set proposal**. Deterministic, tested code validates it and applies it.

### Proposal format

A Zod schema in `packages/domain` defines a list of operations (a discriminated union):

- `task.create`, `task.complete`, `task.reopen`, `task.update` (kinds: task, issue, purchase)
- `resource.consume`, `resource.restock`, `resource.adjust`, `resource.create`
- `metric.record`
- `plan.add`, `plan.remove`, `plan.move`
- `note.add`

Each operation has:

- `confidence` from 0 to 1,
- `evidence`: the exact fragment of the transcript it comes from,
- references to existing entities **by ID** from the context it received, or a `create` operation if nothing matches,
- an optional `clarification` with a question and suggested answers (for example "Atlas Plus or Atlas Geoflex?").

### Context sent to the model

The project's open work items, resources with units, metrics, recent entries, the template's vocabulary hints and today's plan. Only data of the calling user's project.

### Validation and apply

1. The model output is parsed and validated against the Zod schema. Invalid output fails the step; it is never "repaired" by guessing.
2. Every referenced ID is checked against the project; units are normalized by code, not by the model.
3. An operation is **auto-applied** only if its confidence is at least the threshold (default 0.85, configurable per user) and its type is on the allowlist of safe operations. Deleting anything is never auto-applied.
4. All other operations wait in `NEEDS_REVIEW`. The user confirms, edits or rejects each one on mobile or web.
5. Applying is a pure domain function (`applyChangeSet(state, operations)`) that returns the writes. It is executed as one DynamoDB transaction (ADR-0006).
6. Every applied change set is stored with before and after values, so **undo** creates the inverse operations.

### Model access

- **Amazon Bedrock** with Claude, called from TypeScript through the Anthropic Bedrock SDK (`@anthropic-ai/bedrock-sdk`, Mantle client).
- **Structured outputs** (`output_config.format`, supported on Bedrock) force the response to match the JSON schema derived from the Zod schema. Server-side Zod validation still runs.
- **Model ID in Parameter Store** per environment, so the model can be changed without a deployment. The MVP starts with Claude Opus 5.5 (`anthropic.claude-opus-5-5`); the effort level is tuned with the evaluation set below. A switch to a cheaper model such as Claude Haiku 5.5 happens only if the evaluation set shows equal quality, and is recorded in a new ADR.
- Before the first deployment, verify that the model is available in `eu-central-1` (directly or through a cross-region inference profile) and that model access is enabled.
- The code checks `stop_reason` before reading the content and handles `refusal` and `max_tokens` as failures of the step.

### Quality

- Unit tests use recorded model responses; they never call Bedrock.
- An **evaluation set** of real Polish transcripts with expected operations lives in the repo. A script (`pnpm eval:extraction`) runs it against Bedrock on demand and reports precision, recall and cost. It is not part of every CI run, because it costs money.

## Consequences

- Wrong AI output can at most create a pending proposal; it cannot silently corrupt data.
- The confidence threshold and the safe-operation list give a clear trade-off between convenience and safety.
- The proposal schema is a contract that grows with the domain; every new operation needs a schema change, an apply function, an inverse for undo and tests.
- The transcript is user data inside the prompt. It is treated as data, never as instructions, and the apply step only accepts operations on the caller's own project.

## Alternatives considered

- **Let the model call write tools directly (agent loop):** fewer components, but no review step, harder to test and harder to undo.
- **Rule-based extraction (regular expressions, keyword lists):** predictable, but fragile for free Polish speech with inflection.
- **Ask the user to confirm every operation:** safest, but defeats the purpose of low-friction input.

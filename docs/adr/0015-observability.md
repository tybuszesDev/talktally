# ADR-0015: Observability

- Status: Accepted
- Date: 2026-11-05

## Context

A dictation passes through the phone, AppSync, S3, EventBridge, Step Functions, Transcribe, Bedrock and DynamoDB. When something fails or is slow, the owner must find out where and why without guessing. The AI step needs its own visibility: which model and prompt produced a change, at what cost, and how often users reject its output. CloudWatch custom metrics are billed per metric, so the metric set must stay small.

## Decision

### Backend

- **Powertools for AWS Lambda (TypeScript)** in every function: Logger (structured JSON), Tracer, Metrics (Embedded Metric Format) and Idempotency.
- **Correlation:**
  - Clients send an `x-correlation-id` header; AppSync passes it to resolvers.
  - In the voice pipeline the `entryId` is the correlation ID: it is the Step Functions execution name and appears in every log line.
- **Tracing:** X-Ray tracing is enabled for AppSync, Lambda and Step Functions. If X-Ray SDK support ends, the Tracer moves to OpenTelemetry (AWS Distro for OpenTelemetry) in a new ADR.
- **Logging rules:** never log transcripts, audio URLs, tokens or other user content. Log IDs, sizes, durations and statuses.
- **Metrics**, with the dimension `Environment` only, to stay at about 10 custom metrics:
  - `EntriesProcessed`, `EntriesFailed`, `PipelineDurationMs`, `TranscriptionSeconds`
  - `ExtractionInputTokens`, `ExtractionOutputTokens`, `ExtractionCostUsd`
  - `OperationsAutoApplied`, `OperationsPendingReview`, `OperationsRejected`

### Service level objectives (prod, rolling 30 days)

| SLO | Target |
|---|---|
| Entries processed without `FAILED` | ≥ 99% |
| Time from upload to proposal, audio ≤ 3 min, p95 | ≤ 120 s |
| AppSync requests without server error | ≥ 99% |
| Auto-applied operations not undone within 24 h | ≥ 95% |

### Alarms

An SNS topic per environment sends email. Alarms in prod: failed Step Functions executions, Lambda errors, AppSync 5xx errors, Bedrock throttling, messages in any dead-letter queue. Budget alarms are separate (ADR-0002).

### Dashboard

One CloudWatch dashboard per environment: pipeline throughput and duration, errors, AI tokens and cost, review outcomes.

### Clients

- **Sentry** for crash and error reporting in the web and mobile apps (free plan). Source maps are uploaded in CI. The release name is the app version.
- No session replay. Personal data is scrubbed before sending.

### AI observability

- Every change set stores the model ID, the prompt version, input and output tokens, latency and estimated cost.
- Prompts are versioned files in the repository. A change of prompt increases its version.
- Results of the evaluation set (ADR-0008) are stored in `docs/evals/` with the date, model and prompt version, and the latest summary is shown in the README.

## Consequences

- Every failure can be traced from the phone to the exact step by one ID.
- The undo rate of auto-applied operations gives a measurable quality signal for the AI.
- Sentry adds a service outside AWS. It is accepted because AWS has no equivalent tool that covers both web and mobile.

## Alternatives considered

- **OpenTelemetry with Grafana Cloud:** vendor-neutral, but more setup and another dashboard tool.
- **Datadog or New Relic:** complete platforms, but paid beyond small trials.
- **CloudWatch RUM:** AWS-native, but web only; mobile would still need another tool.
- **High-cardinality metrics (per user, per project):** more detail, but each dimension combination is a billed custom metric. Per-user detail stays in logs.

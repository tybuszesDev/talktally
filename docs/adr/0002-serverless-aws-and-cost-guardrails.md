# ADR-0002: Serverless on AWS with cost guardrails

- Status: Accepted
- Date: 2026-11-05

## Context

The project is a portfolio piece. It should use many AWS services in a realistic way, but traffic is one user plus occasional demo visitors, and the budget is roughly 100 USD of credits plus a target of under 10 USD per month afterwards. Many AWS services charge per hour whether they are used or not; those would dominate the bill.

## Decision

Use only **pay-per-request or always-free services**, deployed to a single region, **`eu-central-1` (Frankfurt)**. Exceptions, where AWS requires another region: `us-east-1` for ACM certificates used by CloudFront and the AppSync custom domain, and `us-west-2` for AWS Device Farm (ADR-0014), which exists only there.

Services in use:

| Area | Service |
|---|---|
| Identity | Amazon Cognito user pool |
| API | AWS AppSync (GraphQL with subscriptions) |
| Compute | AWS Lambda (Node.js 24, arm64, outside any VPC) |
| Data | Amazon DynamoDB (on-demand capacity) |
| Files | Amazon S3 (audio uploads, web hosting), S3 Glacier Deep Archive (old audio) |
| CDN | Amazon CloudFront with Origin Access Control |
| DNS and TLS | Amazon Route 53 (delegated subdomain), AWS Certificate Manager |
| Orchestration | AWS Step Functions (Standard workflows) |
| Speech to text | Amazon Transcribe (batch, `pl-PL`) |
| AI | Amazon Bedrock (Claude models) |
| Events | Amazon EventBridge (custom bus, Pipes, Scheduler) |
| Configuration | AWS Systems Manager Parameter Store (standard tier) |
| Observability | Amazon CloudWatch (logs, metrics, alarms, dashboard), AWS X-Ray |
| Cost control | AWS Budgets, Cost Anomaly Detection |
| Device testing | AWS Device Farm (real iOS and Android devices) |

Guardrails:

- **Not used:** NAT Gateway, Application Load Balancer, ECS/Fargate, EC2, RDS/Aurora, ElastiCache, OpenSearch, Secrets Manager (Parameter Store SecureString is used instead), Lambda inside a VPC.
- AWS Budgets alarm at 10 USD per month (actual and forecast) and Cost Anomaly Detection, both with email alerts. These are created first, in the bootstrap stack.
- CloudWatch log retention: 14 days in dev, 30 days in prod.
- S3 lifecycle rule moves raw audio to S3 Glacier Deep Archive after 30 days (configurable). Audio is never deleted automatically.
- Per-user quotas: maximum audio length per entry and maximum dictation minutes per day.
- Every resource is tagged `Project`, `Environment`, `ManagedBy=terraform` so Cost Explorer can group costs.

## Expected monthly cost (one active user)

Assumptions: one 3-minute dictation per day, about 30 AI calls for extraction and 30 for plan suggestions.

| Item | Estimate |
|---|---|
| Transcribe, 90 min at about 0.024 USD/min | ~2.20 USD |
| Bedrock, ~60 calls | ~1–3 USD (depends on the model, see ADR-0008) |
| Route 53 hosted zone | 0.50 USD |
| AppSync, Lambda, DynamoDB, S3, CloudFront, Step Functions, Cognito, CloudWatch | ~0–0.50 USD (inside free tiers at this volume) |
| S3 Glacier Deep Archive, ~0.5 GB of audio per year | < 0.01 USD |
| **Total** | **~4–6 USD** |

Not included in the monthly total:

- AWS Device Farm: one-time trial of 1,000 device minutes, then 0.17 USD per device minute. Runs only for releases (ADR-0014).
- Apple Developer Program: 99 USD per year (outside AWS).

These figures are estimates from public price lists. They are checked against the real bill after the first month and the cost report in the README is updated.

## Consequences

- Idle cost is close to zero; the system scales without changes if usage grows.
- Lambda cold starts add latency on the first request after idle periods. Acceptable for this use case.
- Developers must check the price model of every new service before adding it. A new hourly-billed service requires a new ADR.
- Before the first deployment, check in AWS Billing whether the account is on the Free plan or the Paid plan. Some services can be restricted on the Free plan; upgrading keeps the remaining credits. Also check that Bedrock model access is enabled for Anthropic models in the chosen region.

## Alternatives considered

- **Containers on ECS Fargate behind an ALB:** a classic "application server", but the ALB alone costs around 16–20 USD per month and Fargate tasks bill per hour.
- **EC2 free tier instance:** cheap for 12 months, but then it bills every hour, and it adds patching and scaling work that teaches less about AWS-native design.
- **Multiple regions:** no benefit for one user, more cost and complexity.

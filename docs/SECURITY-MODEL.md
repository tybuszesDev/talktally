# Security model

A lightweight threat model (STRIDE) for TalkTally. Update it when a change touches authentication, authorization, IAM, data storage, the AI step or CI.

## Assets

- **User data:** projects, work items, inventory, transcripts, audio recordings.
- **Credentials:** Cognito tokens on devices, AWS roles used by CI, the owner's IAM administrator user.
- **The AWS bill.** Transcription and AI calls cost money per use, so abuse is a financial attack ("denial of wallet").
- **The AWS account and the deployment pipeline.**
- **The public repository** and its history.

## Actors

- Owner and invited users.
- Demo visitors (shared demo account with low quotas).
- Anonymous internet users.
- Contributors opening pull requests from forks of the public repository.
- Authors of third-party dependencies and GitHub Actions.

## Trust boundaries

1. Client apps ↔ AppSync (Cognito token).
2. Client apps ↔ S3 (presigned upload).
3. Voice pipeline ↔ Transcribe and Bedrock.
4. GitHub Actions ↔ AWS (OIDC).
5. Hostinger DNS ↔ Route 53 (NS delegation).

## Threats and mitigations

### Spoofing

- Cognito SRP sign-in, optional TOTP MFA, short-lived access tokens.
- OIDC trust policies match exact subjects in GitHub's immutable format, which contains the owner and repository IDs, so a recycled owner or repository name cannot produce them (ADR-0027).
  - The `plan` role trusts only pull requests of this repository.
  - The `deploy` role trusts only jobs in the `dev` environment (deployments only from `main`) and the `prod` environment (`main` and release tags, approved by the owner).
  - Jobs without an environment, such as Scorecard, cannot deploy, even on `main`.
  - Pull requests from forks get a read-only token and no secrets, so they get no AWS role.
- Backend-only GraphQL mutations accept only IAM authorization, so clients cannot call them.
- The owner's administrator access is an IAM user with passkey MFA. The CLI and Terraform get temporary credentials through `aws login`. No access keys exist for any user, and the root user is used only for account and billing tasks (ADR-0026).

### Tampering

- Upload URLs are scoped to one object key, one content type and a maximum size. The implementation uses a presigned POST policy with `content-length-range`, because a presigned PUT cannot limit the size.
- Change sets are validated with Zod; referenced IDs are checked against the caller's project; DynamoDB writes use condition expressions and versions.
- Branch protection, required checks and actions pinned by commit SHA protect the pipeline.
- CodeQL scans the code and the workflows on every pull request; new high or critical security alerts block the merge. OpenSSF Scorecard rates the repository settings weekly (ADR-0017).

### Repudiation

- Every change set records its origin (user or AI), the model ID and the prompt version, and keeps before and after values.
- CloudTrail management events are kept (one trail, free tier).

### Information disclosure

- Ownership is part of the DynamoDB key design; every resolver verifies the project belongs to the caller. Subscriptions are filtered by the caller's identity. Automated tests cover cross-user access (ADR-0011).
- S3 buckets block public access; the web bucket is read only through CloudFront Origin Access Control.
- Encryption at rest everywhere (AWS-managed keys) and TLS in transit. One exception: the `talktally-alerts` SNS topic is not encrypted at rest. AWS Budgets cannot publish to a topic encrypted with the AWS-managed key, and a customer managed key would cost about 1 USD per month. The topic carries cost alerts only, never user content ([bootstrap README](../infra/terraform/bootstrap/README.md)).
- Logs and Sentry events never contain transcripts, audio URLs or tokens (ADR-0015).
- gitleaks scans staged changes before each commit and every pushed commit in CI; GitHub secret scanning with push protection is enabled.
- According to AWS documentation, Bedrock does not use prompts or outputs to train models. This is verified again before the first prod deployment.

### Denial of service and denial of wallet

- Invite-only sign-up (ADR-0004).
- Per-user quotas: maximum audio length per entry, dictation minutes per day, AI calls per day. The demo account has lower limits.
- Reserved concurrency limits on pipeline Lambdas cap parallel spending.
- Idempotent pipeline starts (execution name = `entryId`).
- AWS Budgets and Cost Anomaly Detection alerts (ADR-0002).

### Elevation of privilege

- One IAM role per Lambda with least privilege; no wildcard actions on data resources.
- CI roles split into read-only `plan` and `deploy` (ADR-0027). The role ARNs are GitHub secrets, so the account ID stays out of the public logs.
  - `plan` has `ReadOnlyAccess` minus reads of user data: S3 objects outside the state bucket, DynamoDB items, log events, X-Ray traces, SQS messages, Step Functions executions, Transcribe results, Cognito users and the owner's contact details (SNS subscription lists, CloudTrail event history, account contact information). Pull request jobs may run code from dependency updates. Its only write is the lock file of an environment stack. Secret values never enter Terraform state, because this role can read the environment state.
  - `deploy` has `PowerUserAccess`, plus IAM only for `talktally-dev-*` and `talktally-prod-*` roles and policies. Each such role must carry the `talktally-workload-boundary` permissions boundary, which excludes IAM, Organizations and account actions.
  - The deploy role and the boundary both deny:
    - account settings and contact details, billing and cost changes;
    - state bucket configuration changes and deleting old state versions;
    - any access to the bootstrap state;
    - changes to the alerts topic and its subscriptions.
  - So CI cannot create users or access keys, change its own trust or the OIDC provider, enroll the account in Organizations, or weaken the cost alerts.
- CI never reads or writes the bootstrap state. A changed state could make the owner's next local `terraform init` install a foreign provider, which `plan` would run with administrator credentials. The owner also runs `terraform init -lockfile=readonly` for the bootstrap stack, so a provider missing from the committed lock file stops the init (ADR-0027). The state bucket policy denies requests through access points, so no second path to the state objects can bypass these denies.
- Dependency install scripts run only for an allowlist; new package versions wait 3 days before use, both in pnpm and in Renovate, which proposes the updates; security updates come right away (ADR-0017).

### AI-specific: prompt injection

- The transcript is user content and is treated as data, never as instructions.
- The model has no tools with side effects; it only returns a proposal.
- Proposals can reference only entities of the caller's project. Auto-apply is limited to safe operation types above the confidence threshold. The worst outcome is a wrong proposal on the user's own data, which can be rejected or undone.

## Privacy

| Data | Where | Retention |
|---|---|---|
| Account (email) | Cognito | until account deletion |
| Projects, work items, inventory, metrics, plans | DynamoDB | until deleted by the user |
| Transcripts and change sets | DynamoDB | until the entry or account is deleted |
| Audio | S3 Standard, then S3 Glacier Deep Archive after 30 days | until the entry or account is deleted |
| Logs | CloudWatch | 14 days (dev), 30 days (prod) |
| Crash reports | Sentry | Sentry plan default |

User rights in the MVP:

- **Data export:** a JSON archive of all the user's data, delivered through a time-limited download link.
- **Account deletion** from inside the app (also required by Apple for apps that offer account creation). It removes Cognito, DynamoDB and S3 data.
- A **privacy policy** page at `talktally.tybu.com/privacy`, required for TestFlight and the App Store.

## Controls considered and not used

| Control | Reason | Revisit when |
|---|---|---|
| AWS WAF | Monthly fee per web ACL and per rule; invite-only sign-up and quotas cover the risk | Public sign-up is opened |
| Amazon GuardDuty | Paid after the 30-day trial | The account holds more than this project |
| AWS Security Hub | Paid per security check | Same as above |
| AWS Config | Paid per configuration item recorded | Compliance requirements appear |

# ADR-0027: CI access to AWS with GitHub OIDC roles

- Status: Accepted
- Date: 2026-11-14
- Amends: [ADR-0003](0003-terraform-infrastructure-as-code.md) (which jobs may assume the deploy role) and [ADR-0012](0012-git-workflow-and-ci-cd.md) (one deploy role for dev and prod)

## Context

ADR-0003 gives GitHub Actions two IAM roles through OIDC: a read-only `plan` role for pull requests and a `deploy` role restricted to the `main` branch and the `prod` GitHub environment. ADR-0012 applies dev after each merge to `main` and deploys prod from a release tag or a manual run, behind the `prod` environment with approval.

Facts that shape the details:

- **Subject format.** Repositories created after July 15, 2026 use an immutable subject format that contains the owner ID and the repository ID ([GitHub OIDC reference](https://docs.github.com/en/actions/reference/security/oidc)). For this repository, `GET /repos/tybuszesDev/talktally/actions/oidc/customization/sub` ([REST API](https://docs.github.com/en/rest/actions/oidc)) returns the prefix `repo:tybuszesDev@58275357/talktally@1447250076`. Someone who later registers a recycled owner or repository name cannot produce it.
- **Subject suffixes.** A job that references an environment gets `:environment:<name>`. A pull request job without an environment gets `:pull_request`. Any other job gets `:ref:refs/heads/<branch>`. AWS does not support customized subject claims ("Support for custom claims for OIDC is unavailable in AWS", [GitHub docs for AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)).
- **IAM checks the trust policy.** IAM rejects a trust policy for `token.actions.githubusercontent.com` that has no `sub` condition, or one that is only a wildcard ([IAM: roles for OIDC](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html)).
- **Jobs on `main` with `id-token: write`.** Every such job gets the subject `ref:refs/heads/main`. The Scorecard workflow already has this permission to sign its results, and it runs third-party code.
- **Fork pull requests.** "The `GITHUB_TOKEN` has read-only permissions in pull requests from forked repositories", and secrets are not passed to them ([events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)). Fetching an OIDC token needs the write permission `id-token: write`.
- **Who pushes pull request branches.** Branches in this repository are pushed by the owner, Renovate, the release-please App and CodeRabbit fixes. A dependency update can bring new code into a pull request job.
- **`ReadOnlyAccess` (v192)** includes `s3:Get*`, `dynamodb:Get*`, `Query`, `Scan`, `logs:Get*`, `FilterLogEvents`, `states:GetExecutionHistory` and `cognito-idp:List*` ([policy reference](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/ReadOnlyAccess.html)). It can read recordings, transcripts and user records.
- **`PowerUserAccess` (v12)** allows every action except `iam:*`, `organizations:*` and `account:*`, plus service-linked roles ([policy reference](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/PowerUserAccess.html)). It also allows billing actions such as `payments:*` and `freetier:UpgradeAccountPlan` ([service reference](https://servicereference.us-east-1.amazonaws.com/v1/freetier/freetier.json)).
- **Terraform must create IAM roles** for Lambda functions and other services. A principal that may create roles with any policy is an administrator in practice, unless every role it creates must carry a permissions boundary ([IAM permissions boundaries](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html)).

## Decision

**Identity provider.** An IAM OIDC provider for `https://token.actions.githubusercontent.com` with the audience `sts.amazonaws.com`. It has no thumbprint, because for GitHub AWS validates the certificate with its own trusted root CAs ([IAM: create an OIDC provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)). The provider and both roles live in the bootstrap stack, which the owner applies locally.

**Trust.** The trust policies match `aud` and the full `sub` with `StringEquals`. They use no wildcards and always include the immutable prefix:

| Role | Subjects (`<prefix>` = `repo:tybuszesDev@58275357/talktally@1447250076`) |
|---|---|
| `talktally-ci-plan` | `<prefix>:pull_request` |
| `talktally-ci-deploy` | `<prefix>:environment:dev`, `<prefix>:environment:prod` |

**Deploy only through environments.** The deploy role trusts only jobs that reference the `dev` or `prod` environment. Each environment's protection rules provide the branch restriction from ADR-0003:

- `dev`: deployment branch `main`.
- `prod`: branch `main` and tags `v*`, with the owner as required reviewer.

Jobs without an environment (Scorecard, CodeQL, release) cannot assume the deploy role.

**Plan role permissions:**

- the AWS managed policy `ReadOnlyAccess`;
- write access only to `*.tflock` objects in the state bucket, for S3 state locking;
- an explicit deny on reading user data:
  - S3 objects outside the state bucket;
  - DynamoDB items and stream records;
  - CloudWatch Logs events and queries;
  - Step Functions execution input and history;
  - Cognito user records.

**Deploy role permissions:**

- `PowerUserAccess`.
- IAM access limited to roles and policies named `talktally-dev-*` and `talktally-prod-*`. Creating or changing such a role requires the permissions boundary `talktally-workload-boundary`, and removing a boundary is denied.
- The boundary allows every action except IAM, Organizations and account actions.

**Shared denies.** Both the deploy role and the boundary deny:

- account, billing and cost services: Budgets, Cost Explorer and Cost Anomaly Detection, Free Tier plan changes, payments and Identity Center;
- changes to the state bucket configuration;
- deleting old state versions;
- changes to the alerts topic.

Because of these denies, the deploy role cannot:

- change its own trust, the OIDC provider or the CI roles;
- create IAM users or access keys;
- enroll the account in AWS Organizations (ADR-0026);
- get around these limits through a role it creates itself.

**Workload roles.** Every workload role in `envs/` sets `permissions_boundary` to the boundary policy. The bootstrap stack outputs its ARN.

**Role ARNs.** They are GitHub Actions secrets: the plan role ARN is a repository secret, and the deploy role ARN is an environment secret in `dev` and `prod`. Secrets are masked in logs, so the account ID does not appear in the public workflow logs. `aws-actions/configure-aws-credentials` runs with `mask-aws-account-id`.

**Exclusive management.** Terraform manages the roles' managed policy attachments and inline policies exclusively (`aws_iam_role_policy_attachments_exclusive`, `aws_iam_role_policies_exclusive`). The next apply removes a policy that was added by hand.

## Consequences

- One deploy role serves both environments, so a dev job has the same AWS permissions as a prod job. The prod approval controls when prod changes, not what a dev job could do. Separate AWS accounts per environment (an alternative in ADR-0003) would close this gap.
- Every workload role needs the boundary and the environment prefix in its name, or the apply fails with `AccessDenied`. The bootstrap stack outputs the boundary ARN for the environment stacks.
- The plan role's deny list can block the refresh of a resource whose read is a data read. For example, a Cognito user managed in Terraform needs `AdminGetUser`. Such a change updates the list in the bootstrap stack and in SECURITY-MODEL.
- `ReadOnlyAccess` includes `ssm:GetParameter*`. The feature that adds the first SecureString parameter also adds it to the deny list.
- CI cannot change its own permissions. Every change to the CI roles is applied locally by the owner (ADR-0003).
- The environments are created once by the owner through the GitHub REST API, as documented in the bootstrap README.

## Alternatives considered

- **`AdministratorAccess` for the deploy role:** simplest, but a leaked token from a deploy job would control the whole account, including IAM users, access keys and the CI roles' own trust.
- **Trusting `ref:refs/heads/main` for the deploy role:** the literal reading of ADR-0003, but every job on `main` with `id-token: write` could assume the role, including today's Scorecard job.
- **Separate deploy roles for dev and prod:** in one account they would need the same permissions, so they would add little. Reconsider when environments move to separate accounts.
- **`ViewOnlyAccess` for the plan role:** it lacks reads that Terraform needs to refresh resources, such as `s3:GetBucketPolicy` and `s3:GetBucketVersioning`.
- **A hand-written read-only policy per service:** precise, but every new AWS service would need a bootstrap change before its first plan.
- **A customized subject claim with `job_workflow_ref`:** would restrict roles to one workflow file, but AWS does not support custom claims.

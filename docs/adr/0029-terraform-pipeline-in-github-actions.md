# ADR-0029: Terraform pipeline in GitHub Actions

- Status: Accepted
- Date: 2026-11-15
- Amends: [ADR-0012](0012-git-workflow-and-ci-cd.md) (how the Terraform jobs run and which check is required) and [ADR-0017](0017-code-quality-security-and-cost-checks.md) (how Trivy runs; costs are watched in AWS instead of by Infracost)

## Context

ADR-0003, ADR-0012 and ADR-0017 require for every pull request that changes infrastructure: `terraform fmt -check`, `terraform validate`, TFLint, Trivy, `terraform test`, a plan of dev posted as a comment and an Infracost comment, all as required checks. A merge to `main` applies dev. ADR-0027 gives pull request jobs the read-only `plan` role and jobs in the `dev` and `prod` environments the `deploy` role.

Facts that shape the details:

- **Required checks and skipped runs.** "A workflow is skipped by path filtering ... Associated checks stay in a "Pending" state and block merging." A job skipped by a conditional "reports "Success"", and for a required check that depends on other jobs GitHub recommends `always()` with `needs` ([troubleshooting required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)).
- **Masking covers logs only.** "GitHub automatically redacts the following sensitive information from workflow logs" ([secrets reference](https://docs.github.com/en/actions/reference/security/secrets)). `aws-actions/configure-aws-credentials` masks the account ID in the same way. A pull request comment or an artifact is not a log, and in a public repository anyone who can read the repository can read both ([downloading artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)). A plan shows ARNs, which contain the account ID.
- **`aquasecurity/trivy-action` was compromised.** In March 2026 an attacker moved most of its version tags to commits with an infostealer; `setup-trivy` and the Trivy 0.69.4 release were affected too ([Snyk](https://snyk.io/articles/trivy-github-actions-supply-chain-compromise/), [CrowdStrike](https://crowdstrike.com/en-us/blog/from-scanner-to-stealer-inside-the-trivy-action-supply-chain-compromise)).
- **AWS first.** TalkTally shows work with AWS. Whatever AWS can do is done with AWS, free AWS services come first, and AWS is the only vendor that may bill the project.
- **Infracost needs a third-party account.** [Infracost CI](https://github.com/infracost/ci) v2 needs a token from Infracost Cloud and uploads every run, with the pull request metadata, to it ([Infracost GitHub Actions docs](https://www.infracost.io/docs/integrations/github_actions/)). A first run on this pull request worked, and the new account had already started a 14-day trial of a paid tagging policy.
- **Costs here come from usage.** ADR-0002 allows only pay-per-request or free services. The Infracost run estimated 0 USD for both environments. What can raise the bill is usage, which AWS Budgets (10 USD, alerts at 50% and 100% and on the forecast) and Cost Anomaly Detection (alerts from 1 USD) already watch in the bootstrap stack. Budgets without actions are free ([AWS Budgets pricing](https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/)).
- **AWS Pricing Calculator** has an API whose workload estimates are free ([Pricing Calculator](https://docs.aws.amazon.com/cost-management/latest/userguide/pricing-calculator.html)). It needs the usage of each service as input; nothing turns a Terraform plan into that usage.
- **TFLint and modules.** TFLint reports an issue inside a called module only when it comes from a variable passed to the module; "Rules that evaluate syntax rather than content should ignore child modules" ([calling modules](https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/calling-modules.md)). The rule `aws_resource_missing_tags` counts the provider's `default_tags` ([rule source](https://github.com/terraform-linters/tflint-ruleset-aws/blob/v0.50.0/rules/aws_resource_missing_tags.go)), so it works on resources of a root module, not on a module inspected on its own.
- **Renovate knows the setup actions.** It updates the `terraform_version` input of `hashicorp/setup-terraform` and the `tflint_version` input of `terraform-linters/setup-tflint` ([known actions](https://github.com/renovatebot/renovate/blob/main/lib/modules/manager/github-actions/known-actions/github-releases.ts)), the TFLint plugin versions in `.tflint.hcl`, and images pinned by digest in workflows.

## Decision

**Root modules.** `infra/terraform/envs/dev` and `infra/terraform/envs/prod`, with state keys `envs/<env>/terraform.tfstate` in the bootstrap bucket. Each sets `default_tags` (`Project`, `Environment`, `ManagedBy`) on its provider and names resources with the prefix `talktally-<env>-`. Each creates one resource now: a resource group `talktally-<env>-resources` that selects the environment's resources by tag, so the apply proves the deploy role, the naming and the tags. There is no shared environment module: TFLint could not check the tags of resources inside it. Feature modules under `modules/` come with the features that need them.

**One workflow, `.github/workflows/terraform.yml`.** It runs on every pull request and on pushes to `main` that change `infra/terraform/` or the workflow.

| Job | Runs | Permissions | Does |
|---|---|---|---|
| Detect Terraform changes | pull requests | `pull-requests: read` | Lists the changed files, including the old paths of renamed files; the other jobs run only when `infra/terraform/` or the workflow changed. |
| Terraform checks | Terraform changed | `contents: read`, no AWS | `fmt -check`, Trivy, then `init -backend=false -lockfile=readonly`, `validate` and `test` in every directory with a dependency lock file, then TFLint. Every check runs even when an earlier one failed. |
| Plan dev | Terraform changed, not a fork | `id-token: write`, plan role | Checks that the role cannot write state or read the bootstrap state, plans dev, and uploads the plan as text with the account ID replaced by `<account-id>`. The binary plan never leaves the runner. |
| Plan comment | after Plan dev | `pull-requests: write`, no AWS | Creates or updates one comment with the plan, found by a marker. |
| Terraform | every pull request, `always()` | none | The required check. Passes when nothing changed; otherwise only when every job above succeeded. A fork's Terraform change therefore fails it, because forks get no plan. |
| Apply dev | pushes to `main` | `id-token: write`, deploy role, environment `dev` | A fresh plan of `main`, then `terraform apply` of that saved plan. |

Rules:

- **No job holds AWS credentials and a token that writes to the pull request.** The plan job hands masked text to the comment job.
- **Plans take the state lock** and wait up to five minutes for another plan or an apply (`-lock-timeout=5m`).
- **Pinned tools.** Terraform and TFLint versions are inputs of their setup actions, the TFLint AWS plugin version is in `.tflint.hcl`, and Renovate updates all three. Trivy runs from its official GHCR image pinned by digest, not through `trivy-action`. GHCR gives no release dates, so Renovate waits for approval in the Dependency Dashboard, as for the gitleaks image.
- **Trivy fails on every finding.** An accepted finding is ignored inline, next to the resource, with the reason (`#trivy:ignore:<id>`, [Trivy docs](https://trivy.dev/docs/latest/guide/scanner/misconfiguration/config/config/)).
- **Costs are watched in AWS, not estimated in the pull request.** No Infracost or other third-party cost service. Before the merge, the reviewer reads the plan: a resource of a new paid service needs an ADR (ADR-0002). After the apply, AWS Budgets and Cost Anomaly Detection alert on any rise. Activating `Project` and `Environment` as cost allocation tags, so costs split by environment, is a separate issue (#92).
- **prod gets static checks only.** Its plan and its approved apply come with F-65.
- **Ruleset.** After the merge, the ruleset of `main` requires the check `Terraform`.

## Consequences

- Every pull request runs two short jobs even without Terraform changes; in exchange the required check never stays pending.
- A cost rise caused by a change shows after the apply to dev, through the AWS alerts, not as a number in the pull request. With pay-per-request services, a number before the merge would be 0 USD or a guess about usage.
- No third-party account or token is involved; the pipeline depends only on GitHub and AWS, plus open-source tools that run inside the job.
- Pull request comments show resource names and the masked plan. The account ID stays out of them, as it stays out of the logs.
- dev changes without approval after each merge. prod waits for F-65 and the `prod` environment's approval.
- A new root module is picked up by the static checks through its lock file; its plan and apply jobs are added by hand.
- When feature modules arrive, their tag coverage comes from the root module's `default_tags`. A resource type that cannot use `default_tags` needs its own check in that feature.

## Alternatives considered

- **`paths` filter on the pull request trigger:** simpler, but a required check would stay pending on every pull request without Terraform changes.
- **`aquasecurity/trivy-action`:** the usual way to run Trivy, but its tags were rewritten by an attacker; an image pinned by digest is the same pattern as gitleaks.
- **Infracost CI or the Infracost GitHub App:** a cost comment on every pull request, but a third-party account that receives the pull request metadata and offers paid features, against the AWS-first rule. For this stack its estimate is 0 USD.
- **AWS Pricing Calculator workload estimates from CI:** AWS and free, but turning a Terraform plan into usage lines is a project of its own, and the result would still be a guess about usage.
- **A third-party action for plan comments, such as tfcmt:** another dependency for about 30 lines of shell.
- **Posting the comment from the plan job:** one job less, but it would hold AWS credentials and a token that writes to the pull request.
- **Applying the plan saved by the pull request:** `main` may have moved since the plan, so a stale plan could be applied or fail.
- **A shared module for both environments:** less duplication, but TFLint could not check the tags of its resources.
- **Planning prod in every pull request:** earlier drift detection, but more output before prod exists; F-65 adds it.
- **HCP Terraform or Atlantis:** remote runs and plan comments built in, but an extra service or server, and state outside the bootstrap bucket.

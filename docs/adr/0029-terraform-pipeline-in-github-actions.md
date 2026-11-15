# ADR-0029: Terraform pipeline in GitHub Actions

- Status: Accepted
- Date: 2026-11-15
- Amends: [ADR-0012](0012-git-workflow-and-ci-cd.md) (how the Terraform jobs run and which check is required) and [ADR-0017](0017-code-quality-security-and-cost-checks.md) (how Trivy and Infracost run)

## Context

ADR-0003, ADR-0012 and ADR-0017 require for every pull request that changes infrastructure: `terraform fmt -check`, `terraform validate`, TFLint, Trivy, `terraform test`, a plan of dev posted as a comment and an Infracost comment, all as required checks. A merge to `main` applies dev. ADR-0027 gives pull request jobs the read-only `plan` role and jobs in the `dev` and `prod` environments the `deploy` role.

Facts that shape the details:

- **Required checks and skipped runs.** "A workflow is skipped by path filtering ... Associated checks stay in a "Pending" state and block merging." A job skipped by a conditional "reports "Success"", and for a required check that depends on other jobs GitHub recommends `always()` with `needs` ([troubleshooting required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)).
- **Masking covers logs only.** "GitHub automatically redacts the following sensitive information from workflow logs" ([secrets reference](https://docs.github.com/en/actions/reference/security/secrets)). `aws-actions/configure-aws-credentials` masks the account ID in the same way. A pull request comment or an artifact is not a log, and in a public repository anyone who can read the repository can read both ([downloading artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)). A plan shows ARNs, which contain the account ID.
- **`aquasecurity/trivy-action` was compromised.** In March 2026 an attacker moved most of its version tags to commits with an infostealer; `setup-trivy` and the Trivy 0.69.4 release were affected too ([Snyk](https://snyk.io/articles/trivy-github-actions-supply-chain-compromise/), [CrowdStrike](https://crowdstrike.com/en-us/blog/from-scanner-to-stealer-inside-the-trivy-action-supply-chain-compromise)).
- **Infracost moved to v2.** The [Infracost CI](https://github.com/infracost/ci) image (Apache-2.0) runs `infracost-ci diff --base-path <base> --head-path <head>`, which parses the Terraform code of both checkouts, needs no plan and no cloud credentials, posts or updates one pull request comment and uploads the run to Infracost Cloud. It needs a CLI v2 token in `INFRACOST_CLI_AUTHENTICATION_TOKEN`; a v0.1 API key "is not accepted". The older `infracost/actions/setup` flow is marked legacy. "Code is parsed inside the runner. Only the cost estimate and the pull request metadata reach Infracost Cloud" ([Infracost GitHub Actions docs](https://www.infracost.io/docs/integrations/github_actions/)). The free CI/CD plan allows 1000 runs per month ([pricing](https://www.infracost.io/pricing/)).
- **TFLint and modules.** TFLint reports an issue inside a called module only when it comes from a variable passed to the module; "Rules that evaluate syntax rather than content should ignore child modules" ([calling modules](https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/calling-modules.md)). The rule `aws_resource_missing_tags` counts the provider's `default_tags` ([rule source](https://github.com/terraform-linters/tflint-ruleset-aws/blob/v0.50.0/rules/aws_resource_missing_tags.go)), so it works on resources of a root module, not on a module inspected on its own.
- **Renovate knows the setup actions.** It updates the `terraform_version` input of `hashicorp/setup-terraform` and the `tflint_version` input of `terraform-linters/setup-tflint` ([known actions](https://github.com/renovatebot/renovate/blob/main/lib/modules/manager/github-actions/known-actions/github-releases.ts)), the TFLint plugin versions in `.tflint.hcl`, and images pinned by digest in workflows.

## Decision

**Root modules.** `infra/terraform/envs/dev` and `infra/terraform/envs/prod`, with state keys `envs/<env>/terraform.tfstate` in the bootstrap bucket. Each sets `default_tags` (`Project`, `Environment`, `ManagedBy`) on its provider and names resources with the prefix `talktally-<env>-`. Each creates one resource now: a resource group `talktally-<env>-resources` that selects the environment's resources by tag, so the apply proves the deploy role, the naming and the tags. There is no shared environment module: TFLint could not check the tags of resources inside it. Feature modules under `modules/` come with the features that need them.

**One workflow, `.github/workflows/terraform.yml`.** It runs on every pull request and on pushes to `main` that change `infra/terraform/` or the workflow.

| Job | Runs | Permissions | Does |
|---|---|---|---|
| Detect Terraform changes | pull requests | `pull-requests: read` | Lists the changed files; the other jobs run only when `infra/terraform/` or the workflow changed. |
| Terraform checks | Terraform changed | `contents: read`, no AWS | `fmt -check`, Trivy, then `init -backend=false -lockfile=readonly`, `validate` and `test` in every directory with a dependency lock file, then TFLint. Every check runs even when an earlier one failed. |
| Plan dev | Terraform changed, not a fork | `id-token: write`, plan role | Checks that the role cannot write state or read the bootstrap state, plans dev, and uploads the plan as text with the account ID replaced by `<account-id>`. The binary plan never leaves the runner. |
| Plan comment | after Plan dev | `pull-requests: write`, no AWS | Creates or updates one comment with the plan, found by a marker. |
| Infracost | Terraform changed, not a fork | `pull-requests: write`, no AWS | `infracost-ci diff` on the base and head commits; creates or updates one cost comment. |
| Terraform | every pull request, `always()` | none | The required check. Passes when nothing changed; otherwise only when every job above succeeded. A fork's Terraform change therefore fails it, because forks get no plan. |
| Apply dev | pushes to `main` | `id-token: write`, deploy role, environment `dev` | A fresh plan of `main`, then `terraform apply` of that saved plan. |

Rules:

- **No job holds AWS credentials and a token that writes to the pull request.** The plan job hands masked text to the comment job.
- **Plans take the state lock** and wait up to five minutes for another plan or an apply (`-lock-timeout=5m`).
- **Pinned tools.** Terraform and TFLint versions are inputs of their setup actions, the TFLint AWS plugin version is in `.tflint.hcl`, and Renovate updates all three. Trivy and Infracost CI run from their official GHCR images pinned by digest, not through `trivy-action` or `infracost/actions`. GHCR gives no release dates, so Renovate waits for approval in the Dependency Dashboard, as for the gitleaks image.
- **Trivy fails on every finding.** An accepted finding is ignored inline, next to the resource, with the reason (`#trivy:ignore:<id>`, [Trivy docs](https://trivy.dev/docs/latest/guide/scanner/misconfiguration/config/config/)).
- **Infracost** uses the token in the repository secret `INFRACOST_CLI_AUTHENTICATION_TOKEN`, created by the owner (setup in `infra/terraform/README.md`).
- **prod gets static checks only.** Its plan and its approved apply come with F-65.
- **Ruleset.** After the merge, the ruleset of `main` requires the check `Terraform`.

## Consequences

- Every pull request runs two short jobs even without Terraform changes; in exchange the required check never stays pending.
- Merging a Terraform change needs Infracost Cloud to be reachable. If it is down, the check fails until a re-run passes.
- Infracost Cloud receives the cost estimate and pull request metadata (title, author, branch, commit). The repository is public, so this data is public already.
- Pull request comments show resource names and the masked plan. The account ID stays out of them, as it stays out of the logs.
- dev changes without approval after each merge. prod waits for F-65 and the `prod` environment's approval.
- A new root module is picked up by the static checks through its lock file; its plan and apply jobs are added by hand.
- When feature modules arrive, their tag coverage comes from the root module's `default_tags`. A resource type that cannot use `default_tags` needs its own check in that feature.

## Alternatives considered

- **`paths` filter on the pull request trigger:** simpler, but a required check would stay pending on every pull request without Terraform changes.
- **`aquasecurity/trivy-action`:** the usual way to run Trivy, but its tags were rewritten by an attacker; an image pinned by digest is the same pattern as gitleaks.
- **The Infracost GitHub App:** no workflow code, but a third-party app with access to the repository, outside the required checks.
- **`infracost/actions/setup` with the v0.10 CLI:** marked legacy; its API key does not work with v2.
- **A third-party action for plan comments, such as tfcmt:** another dependency for about 30 lines of shell.
- **Posting the comment from the plan job:** one job less, but it would hold AWS credentials and a token that writes to the pull request.
- **Applying the plan saved by the pull request:** `main` may have moved since the plan, so a stale plan could be applied or fail.
- **A shared module for both environments:** less duplication, but TFLint could not check the tags of its resources.
- **Planning prod in every pull request:** earlier drift detection, but more output before prod exists; F-65 adds it.
- **HCP Terraform or Atlantis:** remote runs and plan comments built in, but an extra service or server, and state outside the bootstrap bucket.

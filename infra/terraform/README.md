# Terraform

All AWS infrastructure of TalkTally ([ADR-0003](../../docs/adr/0003-terraform-infrastructure-as-code.md)). The pipeline that checks, plans and applies it is described in [ADR-0029](../../docs/adr/0029-terraform-pipeline-in-github-actions.md).

| Path | Content | Applied by |
|---|---|---|
| [`bootstrap/`](bootstrap/README.md) | Account-level resources: state bucket, budgets and alerts, CI roles, DNS zones | The owner, locally |
| `envs/dev/` | Root module of the dev environment, state key `envs/dev/terraform.tfstate` | CI, on every merge to `main` that changes `infra/terraform/` |
| `envs/prod/` | Root module of the prod environment, state key `envs/prod/terraform.tfstate` | Nobody yet: plan and approved apply come with F-65 |
| `.tflint.hcl` | TFLint rules for every root module | — |

Each environment has the resource group `talktally-<env>-resources`. It lists every resource of the environment in the AWS console (Resource Groups), selected by the tags below.

| File (`envs/dev/`) | Resources |
|---|---|
| `main.tf` | Resource group |
| `auth.tf` | Cognito user pool `talktally-dev-users` with the app clients `web` and `mobile` ([ADR-0032](../../docs/adr/0032-user-pool-settings-and-invitations.md)); outputs in `outputs.tf`. Users are invited with `pnpm invite` ([CONTRIBUTING](../../CONTRIBUTING.md#inviting-users)) |

`envs/prod/` holds only the resource group until F-65.

## Rules for new resources

- **Names** start with `talktally-<env>-` (`local.name_prefix`). For IAM roles and policies the deploy role allows nothing else ([ADR-0027](../../docs/adr/0027-ci-access-to-aws-with-github-oidc-roles.md)).
- **Tags** come from `default_tags` in each root module's `providers.tf`: `Project`, `Environment`, `ManagedBy`. TFLint fails a resource that would end up without them.
- **IAM roles** set `permissions_boundary` to the policy `talktally-workload-boundary`, found by name.
- **Bootstrap resources** (state bucket, alerts topic, boundary policy, app zone) are found with data sources by name, never with `terraform_remote_state`: CI must not read the bootstrap state.
- **Secret values** never enter state: create them outside Terraform or use write-only arguments such as `value_wo`.
- **Cost:** only pay-per-request or free services; a new paid service needs an ADR ([ADR-0002](../../docs/adr/0002-serverless-aws-and-cost-guardrails.md)). Check the plan for new resource types before the merge. After the apply, AWS Budgets and Cost Anomaly Detection alert on any rise ([bootstrap README](bootstrap/README.md)).

## Pull requests and merges

The workflow [`terraform.yml`](../../.github/workflows/terraform.yml) runs on every pull request. When the pull request changes `infra/terraform/` or the workflow:

- **Terraform checks:** `terraform fmt -check`, Trivy, then `init`, `validate` and `test` in every directory with a `.terraform.lock.hcl`, then TFLint. No AWS credentials.
- **Plan dev:** a plan with the read-only plan role. The comment "Terraform plan: dev" shows it, with the account ID replaced by `<account-id>`.
- **Terraform:** the required check. It passes when nothing under `infra/terraform/` changed, and otherwise only when every job above succeeded.

After the merge, the job "Apply dev" plans `main` again and applies it with the deploy role, in the GitHub environment `dev`.

## Local checks

The same checks as CI, from the repository root. Install the tools once: `brew install --cask terraform-linters/tap/tflint` (the maintainers' tap; TFLint left Homebrew core in v0.63.0) and `brew install trivy` (Terraform: [CONTRIBUTING](../../CONTRIBUTING.md#prerequisites)).

```sh
terraform fmt -check -recursive infra/terraform
trivy config --exit-code 1 --skip-dirs '**/.terraform' infra/terraform
for dir in infra/terraform/bootstrap infra/terraform/envs/dev infra/terraform/envs/prod; do
  terraform -chdir="$dir" init -backend=false -lockfile=readonly
  terraform -chdir="$dir" validate
  terraform -chdir="$dir" test
done
(cd infra/terraform && tflint --init --config "$(pwd)/.tflint.hcl" && tflint --recursive --config "$(pwd)/.tflint.hcl")
```

The tests mock the AWS provider: they create nothing and need no credentials.

Trivy fails on every finding. To accept one, put `#trivy:ignore:<id>` with the reason on the lines right above the resource ([Trivy docs](https://trivy.dev/docs/latest/guide/scanner/misconfiguration/config/config/)).

## Providers

Each root module has its own `.terraform.lock.hcl` with checksums for macOS (`darwin_arm64`) and the CI runners (`linux_amd64`). CI runs `init -lockfile=readonly`, so a provider missing from the lock file fails the run. After a deliberate provider change, update the lock file of that root module and commit it:

```sh
terraform -chdir=infra/terraform/envs/dev init -backend=false -upgrade
terraform -chdir=infra/terraform/envs/dev providers lock -platform=darwin_arm64 -platform=linux_amd64
```

## Planning dev locally

Changes to dev go through pull requests and the apply after the merge. To look at the real plan before pushing, use the administrator session ([ADR-0026](../../docs/adr/0026-admin-access-with-iam-user-and-aws-login.md)):

```sh
aws login --profile talktally-admin
export AWS_PROFILE=talktally-admin
terraform -chdir=infra/terraform/envs/dev init -lockfile=readonly
terraform -chdir=infra/terraform/envs/dev plan
```

Do not apply locally: the apply after the merge would then find no changes, and the pull request plan would not match what was applied.

# Terraform

All AWS infrastructure of TalkTally ([ADR-0003](../../docs/adr/0003-terraform-infrastructure-as-code.md)). The pipeline that checks, plans and applies it is described in [ADR-0029](../../docs/adr/0029-terraform-pipeline-in-github-actions.md).

| Path | Content | Applied by |
|---|---|---|
| [`bootstrap/`](bootstrap/README.md) | Account-level resources: state bucket, budgets and alerts, CI roles, DNS zones | The owner, locally |
| `envs/dev/` | Root module of the dev environment, state key `envs/dev/terraform.tfstate` | CI, on every merge to `main` that changes `infra/terraform/` |
| `envs/prod/` | Root module of the prod environment, state key `envs/prod/terraform.tfstate` | Nobody yet: plan and approved apply come with F-65 |
| `.tflint.hcl` | TFLint rules for every root module | — |

Today each environment holds one resource: the resource group `talktally-<env>-resources`. It lists every resource of the environment in the AWS console (Resource Groups), selected by the tags below.

## Rules for new resources

- **Names** start with `talktally-<env>-` (`local.name_prefix`). For IAM roles and policies the deploy role allows nothing else ([ADR-0027](../../docs/adr/0027-ci-access-to-aws-with-github-oidc-roles.md)).
- **Tags** come from `default_tags` in each root module's `providers.tf`: `Project`, `Environment`, `ManagedBy`. TFLint fails a resource that would end up without them.
- **IAM roles** set `permissions_boundary` to the policy `talktally-workload-boundary`, found by name.
- **Bootstrap resources** (state bucket, alerts topic, boundary policy, app zone) are found with data sources by name, never with `terraform_remote_state`: CI must not read the bootstrap state.
- **Secret values** never enter state: create them outside Terraform or use write-only arguments such as `value_wo`.
- **Cost:** a new paid service needs an ADR ([ADR-0002](../../docs/adr/0002-serverless-aws-and-cost-guardrails.md)); the Infracost comment shows the difference.

## Pull requests and merges

The workflow [`terraform.yml`](../../.github/workflows/terraform.yml) runs on every pull request. When the pull request changes `infra/terraform/` or the workflow:

- **Terraform checks:** `terraform fmt -check`, Trivy, then `init`, `validate` and `test` in every directory with a `.terraform.lock.hcl`, then TFLint. No AWS credentials.
- **Plan dev:** a plan with the read-only plan role. The comment "Terraform plan: dev" shows it, with the account ID replaced by `<account-id>`.
- **Infracost:** the comment with the monthly cost difference.
- **Terraform:** the required check. It passes when nothing under `infra/terraform/` changed, and otherwise only when every job above succeeded.

After the merge, the job "Apply dev" plans `main` again and applies it with the deploy role, in the GitHub environment `dev`.

## Local checks

The same checks as CI, from the repository root. Install the tools once: `brew install tflint trivy` (Terraform: [CONTRIBUTING](../../CONTRIBUTING.md#prerequisites)).

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

## Infracost

The job "Infracost" runs [Infracost CI](https://github.com/infracost/ci). It reads the Terraform code of the base and head commits, needs no AWS credentials, and posts the cost comment. It uploads the estimate and the pull request metadata (title, author, branch, commit) to Infracost Cloud. One-time setup by the owner:

1. Sign up at [dashboard.infracost.io](https://dashboard.infracost.io). The free CI/CD plan allows 1000 runs per month.
2. Create a token: Organization settings → CLI tokens → **Create CLI v2 tokens**. An older v0.1 API key (`ico-…`) does not work.
3. Store it as a repository secret. `gh` asks for the value, so it does not end up in the shell history:

   ```sh
   gh secret set INFRACOST_CLI_AUTHENTICATION_TOKEN --repo tybuszesDev/talktally
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

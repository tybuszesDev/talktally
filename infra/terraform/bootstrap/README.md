# Bootstrap stack

Account-level resources that every other stack depends on. They are applied once, locally, by the owner ([ADR-0003](../../../docs/adr/0003-terraform-infrastructure-as-code.md)).

| Resource | Purpose |
|---|---|
| S3 bucket `talktally-tfstate-3af2cc3e` | Terraform state for all root modules, each under its own key. It has versioning, SSE-S3 encryption, all public access blocked, ACLs disabled and a TLS-only bucket policy. Old state versions expire after 90 days; the 10 newest are always kept. Locking uses S3 lock files (`use_lockfile`), so there is no DynamoDB table. |
| SNS topic `talktally-alerts` | One topic for all alerts, with the owner's email subscribed. AWS Budgets and Cost Anomaly Detection may publish to it. |
| AWS Budgets `talktally-monthly` | 10 USD per month ([ADR-0002](../../../docs/adr/0002-serverless-aws-and-cost-guardrails.md)). It alerts at 50% and 100% of actual cost and at 100% of forecast cost. |
| Cost Anomaly Detection | The AWS services monitor (`Default-Services-Monitor`, adopted by import) and the subscription `talktally-anomalies`. It sends individual alerts for anomalies of 1 USD or more. |
| IAM OIDC provider `token.actions.githubusercontent.com` | Lets GitHub Actions assume IAM roles with short-lived tokens, so no AWS keys are stored ([ADR-0027](../../../docs/adr/0027-ci-access-to-aws-with-github-oidc-roles.md)). |
| IAM role `talktally-ci-plan` | For pull request jobs of this repository. `ReadOnlyAccess`, minus reads of user data: S3 objects outside the state bucket, the bootstrap state, DynamoDB items, log events, X-Ray traces, SQS messages, Step Functions executions, Transcribe results and Cognito users. It may write only the lock files of the environment stacks (`envs/*.tflock`). |
| IAM role `talktally-ci-deploy` | For jobs in the `dev` and `prod` GitHub environments. `PowerUserAccess`, plus IAM for roles and policies named `talktally-dev-*` and `talktally-prod-*`. Each such role must carry the boundary below. |
| IAM policy `talktally-workload-boundary` | Permissions boundary of every role the deploy role creates: no IAM, Organizations or account actions. |

Design notes:

- **The budget counts cost before credits** (`include_credit = false`). While the Free Tier credits pay the bill, the net cost is 0 USD. A budget on net cost would stay silent until the credits are gone, and on the free plan the account closes then.
- **The topic is not encrypted.** AWS Budgets needs extra KMS key policy permissions to publish to an encrypted topic ([AWS docs](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-sns-policy.html)), and the policy of the AWS-managed SNS key cannot be changed. A customer managed key would cost about 1 USD per month. The alerts carry cost data only.
- **No account ID or email address is committed** ([ADR-0012](../../../docs/adr/0012-git-workflow-and-ci-cd.md)). The account ID is read at run time with `aws_caller_identity`. The email address comes from `private.auto.tfvars`, which git ignores.
- **The CI roles trust exact OIDC subjects.** This repository uses GitHub's immutable subject format, `repo:tybuszesDev@58275357/talktally@1447250076:…`, which contains the owner and repository IDs. A recycled owner or repository name cannot produce it. The plan role trusts `…:pull_request`. The deploy role trusts only `…:environment:dev` and `…:environment:prod`, so jobs without an environment cannot deploy, even on `main`.
- **The deploy role cannot change its own access.** It cannot touch the OIDC provider, the CI roles, IAM users or access keys. Every role it creates must carry `talktally-workload-boundary`. The role and the boundary both deny:
  - account, billing and cost changes, including Budgets, Cost Anomaly Detection, the Free Tier plan and Identity Center;
  - changes to the state bucket configuration and deleting old state versions;
  - any access to the bootstrap state (`bootstrap/*`);
  - changes to the alerts topic and its subscriptions.

  So a role the deploy role creates cannot get around these limits either.
- **CI cannot change these roles.** Terraform owns their policies exclusively: a policy added by hand is removed on the next apply. Changes go through this stack, applied locally.
- **CI never touches this stack's state.** Terraform also installs providers that only the state names ([dependency lock file](https://developer.hashicorp.com/terraform/language/files/dependency-lock)). A changed bootstrap state could therefore run foreign code with the owner's administrator session. Both CI roles are denied the `bootstrap/` keys. The environment stacks find bootstrap resources by name, and the everyday commands below use `-lockfile=readonly`.

## Prerequisites

- Terraform 1.15 or later, because earlier S3 backends cannot use `aws login` credentials. Also the AWS CLI 2.32.0 or later ([CONTRIBUTING](../../../CONTRIBUTING.md#prerequisites)).
- An administrator session ([ADR-0026](../../../docs/adr/0026-admin-access-with-iam-user-and-aws-login.md)):

  ```sh
  aws login --profile talktally-admin
  export AWS_PROFILE=talktally-admin
  ```

- `private.auto.tfvars` with the alert address. Copy it from `private.auto.tfvars.example`.

## Everyday changes

```sh
cd infra/terraform/bootstrap
terraform init -lockfile=readonly
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

`-lockfile=readonly` stops `init` with "Provider dependency changes detected" when the configuration or the state needs a provider that is not in the committed `.terraform.lock.hcl`. Do not continue then: check the state and the change first. Plain `terraform init` is only for a deliberate provider upgrade, and the changed lock file is reviewed in the pull request.

Tests use a mocked AWS provider. They create nothing and need no credentials:

```sh
terraform init -backend=false   # only if the directory is not initialized yet
terraform test
```

## GitHub access

The workflow `.github/workflows/terraform.yml` assumes the roles. It needs two GitHub environments and the role ARNs as secrets. Secrets are masked in the logs, so the account ID stays private. Run these commands once after the roles exist, from this directory, with the `gh` CLI signed in as the owner.

1. Create the environments ([REST API: environments](https://docs.github.com/en/rest/deployments/environments), [deployment branch policies](https://docs.github.com/en/rest/deployments/branch-policies)):

   - `dev`: only `main` may deploy;
   - `prod`: `main` and release tags `v*` may deploy, and the owner approves every job. Self-review stays allowed, because the owner is the only reviewer.

   ```sh
   repo=tybuszesDev/talktally

   gh api -X PUT "repos/$repo/environments/dev" --input - <<'EOF'
   {"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}
   EOF
   gh api -X POST "repos/$repo/environments/dev/deployment-branch-policies" -f name=main -f type=branch

   owner_id="$(gh api user --jq .id)"
   gh api -X PUT "repos/$repo/environments/prod" --input - <<EOF
   {"reviewers": [{"type": "User", "id": $owner_id}], "prevent_self_review": false,
    "deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}
   EOF
   gh api -X POST "repos/$repo/environments/prod/deployment-branch-policies" -f name=main -f type=branch
   gh api -X POST "repos/$repo/environments/prod/deployment-branch-policies" -f name='v*' -f type=tag
   ```

2. Store the role ARNs as secrets. The values go straight from Terraform to GitHub and are never printed:

   ```sh
   terraform output -raw ci_plan_role_arn | gh secret set AWS_PLAN_ROLE_ARN --repo "$repo"
   terraform output -raw ci_deploy_role_arn | gh secret set AWS_DEPLOY_ROLE_ARN --repo "$repo" --env dev
   terraform output -raw ci_deploy_role_arn | gh secret set AWS_DEPLOY_ROLE_ARN --repo "$repo" --env prod
   ```

3. Check that no access keys exist in the account. Expect `0` from the first command and no output from the loop:

   ```sh
   aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent'
   for user in $(aws iam list-users --query 'Users[].UserName' --output text); do
     aws iam list-access-keys --user-name "$user" --query 'AccessKeyMetadata[].AccessKeyId' --output text
   done
   ```

The next pull request that changes `infra/terraform/` runs the job "AWS plan role". After the merge, the job "AWS deploy role" runs in the `dev` environment.

## First apply on a new account

The state bucket is created by this stack, so the first apply uses local state. The state then moves into the bucket.

1. In the Billing console, open Cost Explorer once ("Launch Cost Explorer"). It cannot be enabled through the API. AWS then creates the AWS services monitor. An account can have only one, so Terraform adopts it instead of creating another.
2. Pick a new bucket suffix (`openssl rand -hex 4`). Set it in the backend block in `versions.tf`, in `local.state_bucket_name` in `main.tf` and in the tests.
3. Create a temporary `backend_override.tf`, which git ignores:

   ```hcl
   terraform {
     backend "local" {}
   }
   ```

4. Initialize, import the monitor, and review the plan:

   ```sh
   terraform init
   terraform import aws_ce_anomaly_monitor.services \
     "$(aws ce get-anomaly-monitors --query "AnomalyMonitors[?MonitorName=='Default-Services-Monitor'].MonitorArn | [0]" --output text)"
   terraform plan -out=bootstrap.tfplan
   terraform apply bootstrap.tfplan
   ```

5. Confirm the subscription in the email from AWS Notifications. Then send a test alert:

   ```sh
   aws sns publish --topic-arn "$(terraform output -raw alerts_topic_arn)" \
     --subject "TalkTally test alert" --message "Test message."
   ```

6. Move the state into the bucket, then check it:

   ```sh
   rm backend_override.tf
   terraform init -migrate-state
   aws s3 ls s3://talktally-tfstate-<suffix>/bootstrap/
   rm terraform.tfstate terraform.tfstate.backup
   terraform plan   # expect "No changes"
   ```

7. Set up the environments and secrets in GitHub, as described in [GitHub access](#github-access).

## Free plan

The account is on the AWS Free Tier free plan. It ends six months after the account was created, or when the credits run out, and then the account closes. Before that, upgrade to the paid plan by hand in the Billing console ("Upgrade plan"). Do not enable AWS Organizations or IAM Identity Center while on the free plan ([ADR-0026](../../../docs/adr/0026-admin-access-with-iam-user-and-aws-login.md)).

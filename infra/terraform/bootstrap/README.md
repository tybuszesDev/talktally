# Bootstrap stack

Account-level resources that every other stack depends on. They are applied once, locally, by the owner ([ADR-0003](../../../docs/adr/0003-terraform-infrastructure-as-code.md)).

| Resource | Purpose |
|---|---|
| S3 bucket `talktally-tfstate-3af2cc3e` | Terraform state for all root modules, each under its own key. It has versioning, SSE-S3 encryption, all public access blocked, ACLs disabled and a TLS-only bucket policy. Old state versions expire after 90 days; the 10 newest are always kept. Locking uses S3 lock files (`use_lockfile`), so there is no DynamoDB table. |
| SNS topic `talktally-alerts` | One topic for all alerts, with the owner's email subscribed. AWS Budgets and Cost Anomaly Detection may publish to it. |
| AWS Budgets `talktally-monthly` | 10 USD per month ([ADR-0002](../../../docs/adr/0002-serverless-aws-and-cost-guardrails.md)). It alerts at 50% and 100% of actual cost and at 100% of forecast cost. |
| Cost Anomaly Detection | The AWS services monitor (`Default-Services-Monitor`, adopted by import) and the subscription `talktally-anomalies`. It sends individual alerts for anomalies of 1 USD or more. |

Design notes:

- **The budget counts cost before credits** (`include_credit = false`). While the Free Tier credits pay the bill, the net cost is 0 USD. A budget on net cost would stay silent until the credits are gone, and on the free plan the account closes then.
- **The topic is not encrypted.** AWS Budgets needs extra KMS key policy permissions to publish to an encrypted topic ([AWS docs](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-sns-policy.html)), and the policy of the AWS-managed SNS key cannot be changed. A customer managed key would cost about 1 USD per month. The alerts carry cost data only.
- **No account ID or email address is committed** ([ADR-0012](../../../docs/adr/0012-git-workflow-and-ci-cd.md)). The account ID is read at run time with `aws_caller_identity`. The email address comes from `private.auto.tfvars`, which git ignores.

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
terraform init
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Tests use a mocked AWS provider. They create nothing and need no credentials:

```sh
terraform init -backend=false   # only if the directory is not initialized yet
terraform test
```

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

## Free plan

The account is on the AWS Free Tier free plan. It ends six months after the account was created, or when the credits run out, and then the account closes. Before that, upgrade to the paid plan by hand in the Billing console ("Upgrade plan"). Do not enable AWS Organizations or IAM Identity Center while on the free plan ([ADR-0026](../../../docs/adr/0026-admin-access-with-iam-user-and-aws-login.md)).

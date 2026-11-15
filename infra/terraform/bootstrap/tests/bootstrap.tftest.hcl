# Unit tests for the bootstrap stack. The AWS provider is mocked, so nothing is
# created in AWS and no credentials are needed.
# Run: terraform -chdir=infra/terraform/bootstrap init -backend=false
#      terraform -chdir=infra/terraform/bootstrap test

mock_provider "aws" {
  # Use the defaults below already during plan, so plan-only runs can check
  # values built from them, such as policies that contain ARNs.
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::talktally-tfstate-3af2cc3e"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:eu-central-1:123456789012:talktally-alerts"
    }
  }

  mock_resource "aws_ce_anomaly_monitor" {
    defaults = {
      arn = "arn:aws:ce::123456789012:anomalymonitor/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/talktally-workload-boundary"
    }
  }

  # Two zones of the same type, so each gets its own values by address.
  override_resource {
    target = aws_route53_zone.parent
    values = {
      arn          = "arn:aws:route53:::hostedzone/ZPARENT0000000000000"
      zone_id      = "ZPARENT0000000000000"
      name_servers = ["ns-1.awsdns-01.org", "ns-2.awsdns-02.co.uk", "ns-3.awsdns-03.com", "ns-4.awsdns-04.net"]
    }
  }

  override_resource {
    target = aws_route53_zone.app
    values = {
      arn          = "arn:aws:route53:::hostedzone/ZAPP00000000000000000"
      zone_id      = "ZAPP00000000000000000"
      name_servers = ["ns-5.awsdns-05.org", "ns-6.awsdns-06.co.uk", "ns-7.awsdns-07.com", "ns-8.awsdns-08.net"]
    }
  }
}

variables {
  alert_email = "alerts@example.com"
}

run "state_bucket_is_versioned_encrypted_and_private" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.bucket == "talktally-tfstate-3af2cc3e"
    error_message = "The state bucket name must match the backend block in versions.tf."
  }

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State bucket versioning must be enabled."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "State bucket must use SSE-S3 encryption."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.state.block_public_acls,
      aws_s3_bucket_public_access_block.state.block_public_policy,
      aws_s3_bucket_public_access_block.state.ignore_public_acls,
      aws_s3_bucket_public_access_block.state.restrict_public_buckets,
    ])
    error_message = "All four public access blocks must be on."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "The bucket policy must deny requests without TLS."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s
      if s.Sid == "DenyAccessPointRequests"
      ]) == {
      Sid       = "DenyAccessPointRequests"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = ["arn:aws:s3:::talktally-tfstate-3af2cc3e", "arn:aws:s3:::talktally-tfstate-3af2cc3e/*"]
      Condition = { Null = { "s3:DataAccessPointArn" = "false" } }
    }
    error_message = "The bucket policy must deny every request made through an access point."
  }
}

run "budget_counts_cost_before_credits_and_alerts_the_topic" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly.limit_amount == "10" && aws_budgets_budget.monthly.limit_unit == "USD"
    error_message = "The monthly budget must be 10 USD."
  }

  assert {
    condition     = aws_budgets_budget.monthly.cost_types[0].include_credit == false
    error_message = "The budget must count cost before credits."
  }

  assert {
    condition = toset([for n in aws_budgets_budget.monthly.notification : "${n.notification_type}:${n.threshold}"]) == toset([
      "ACTUAL:50",
      "ACTUAL:100",
      "FORECASTED:100",
    ])
    error_message = "The budget must alert at 50% and 100% actual and 100% forecast."
  }

  assert {
    condition     = alltrue([for n in aws_budgets_budget.monthly.notification : n.subscriber_sns_topic_arns == toset([aws_sns_topic.alerts.arn])])
    error_message = "Every budget notification must go to the alerts topic."
  }
}

run "alerts_topic_accepts_cost_services_and_emails_the_owner" {
  command = plan

  assert {
    condition = toset([
      for s in jsondecode(aws_sns_topic_policy.alerts.policy).Statement : s.Principal.Service
      if can(s.Principal.Service)
    ]) == toset(["budgets.amazonaws.com", "costalerts.amazonaws.com"])
    error_message = "Only AWS Budgets and Cost Anomaly Detection may publish as services."
  }

  assert {
    condition     = aws_sns_topic_subscription.alerts_email.protocol == "email" && aws_sns_topic_subscription.alerts_email.endpoint == "alerts@example.com"
    error_message = "The alert email address must subscribe to the topic."
  }
}

run "anomaly_alerts_are_immediate_from_one_dollar" {
  command = plan

  assert {
    condition     = aws_ce_anomaly_subscription.alerts.frequency == "IMMEDIATE"
    error_message = "Anomaly alerts must be sent immediately."
  }

  assert {
    condition     = aws_ce_anomaly_subscription.alerts.threshold_expression[0].dimension[0].values == toset(["1"])
    error_message = "Anomaly alerts must start at 1 USD."
  }

  assert {
    condition     = one(aws_ce_anomaly_subscription.alerts.subscriber).address == aws_sns_topic.alerts.arn
    error_message = "Anomaly alerts must go to the alerts topic."
  }
}

run "tybu_me_zone_delegates_the_app_subdomain_to_its_own_zone" {
  command = plan

  assert {
    condition     = aws_route53_zone.parent.name == "tybu.me" && aws_route53_zone.app.name == "talktally.tybu.me"
    error_message = "Route 53 must serve tybu.me and the app subdomain in two zones."
  }

  assert {
    condition     = length(aws_route53_zone.parent.vpc) == 0 && length(aws_route53_zone.app.vpc) == 0
    error_message = "Both zones must be public, with no VPC association."
  }

  assert {
    condition = (
      aws_route53_record.app_delegation.zone_id == aws_route53_zone.parent.zone_id &&
      aws_route53_record.app_delegation.name == "talktally.tybu.me" &&
      aws_route53_record.app_delegation.type == "NS"
    )
    error_message = "The tybu.me zone must hold the NS record of the app subdomain."
  }

  assert {
    condition     = aws_route53_record.app_delegation.records == toset(aws_route53_zone.app.name_servers)
    error_message = "The delegation must name the app zone's name servers."
  }

  assert {
    condition     = output.dns_name_servers == aws_route53_zone.parent.name_servers
    error_message = "The output for Hostinger must be the name servers of the tybu.me zone, not the app zone."
  }
}

run "app_zone_has_a_no_mail_spf_record" {
  command = plan

  assert {
    condition = (
      aws_route53_record.app_spf.zone_id == aws_route53_zone.app.zone_id &&
      aws_route53_record.app_spf.name == "talktally.tybu.me" &&
      aws_route53_record.app_spf.type == "TXT"
    )
    error_message = "The SPF record must be the TXT record at the zone apex."
  }

  assert {
    condition     = aws_route53_record.app_spf.records == toset(["v=spf1 -all"])
    error_message = "The SPF record must say that the subdomain sends no mail."
  }
}

run "github_oidc_provider_issues_tokens_for_sts" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.github.url == "https://token.actions.githubusercontent.com"
    error_message = "The OIDC provider must be GitHub Actions."
  }

  assert {
    condition     = toset(aws_iam_openid_connect_provider.github.client_id_list) == toset(["sts.amazonaws.com"])
    error_message = "The only audience must be sts.amazonaws.com."
  }
}

run "plan_role_trusts_only_pull_requests_of_this_repository" {
  command = plan

  assert {
    condition     = length(jsondecode(aws_iam_role.ci_plan.assume_role_policy).Statement) == 1
    error_message = "The plan role must have exactly one trust statement."
  }

  assert {
    condition     = jsondecode(aws_iam_role.ci_plan.assume_role_policy).Statement[0].Principal.Federated == aws_iam_openid_connect_provider.github.arn
    error_message = "The plan role must trust only the GitHub OIDC provider."
  }

  assert {
    condition     = jsondecode(aws_iam_role.ci_plan.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    error_message = "The plan role must require the sts.amazonaws.com audience."
  }

  assert {
    condition     = jsondecode(aws_iam_role.ci_plan.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:tybuszesDev@58275357/talktally@1447250076:pull_request"
    error_message = "The plan role must trust only pull requests of this repository, by its immutable subject."
  }

  assert {
    condition     = toset(keys(jsondecode(aws_iam_role.ci_plan.assume_role_policy).Statement[0].Condition)) == toset(["StringEquals"])
    error_message = "The plan role trust must use exact matches only, no wildcards."
  }
}

run "deploy_role_trusts_only_the_dev_and_prod_environments" {
  command = plan

  assert {
    condition     = length(jsondecode(aws_iam_role.ci_deploy.assume_role_policy).Statement) == 1
    error_message = "The deploy role must have exactly one trust statement."
  }

  assert {
    condition     = jsondecode(aws_iam_role.ci_deploy.assume_role_policy).Statement[0].Principal.Federated == aws_iam_openid_connect_provider.github.arn
    error_message = "The deploy role must trust only the GitHub OIDC provider."
  }

  assert {
    condition     = jsondecode(aws_iam_role.ci_deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    error_message = "The deploy role must require the sts.amazonaws.com audience."
  }

  assert {
    condition = toset(jsondecode(aws_iam_role.ci_deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"]) == toset([
      "repo:tybuszesDev@58275357/talktally@1447250076:environment:dev",
      "repo:tybuszesDev@58275357/talktally@1447250076:environment:prod",
    ])
    error_message = "The deploy role must trust only the dev and prod environments of this repository, not a branch."
  }

  assert {
    condition     = toset(keys(jsondecode(aws_iam_role.ci_deploy.assume_role_policy).Statement[0].Condition)) == toset(["StringEquals"])
    error_message = "The deploy role trust must use exact matches only, no wildcards."
  }
}

run "plan_role_reads_infrastructure_but_not_user_data" {
  command = plan

  assert {
    condition     = toset(aws_iam_role_policy_attachments_exclusive.ci_plan.policy_arns) == toset(["arn:aws:iam::aws:policy/ReadOnlyAccess"])
    error_message = "The plan role must have exactly the ReadOnlyAccess managed policy."
  }

  assert {
    condition     = toset(aws_iam_role_policies_exclusive.ci_plan.policy_names) == toset(["state-lock", "deny-user-data"])
    error_message = "The plan role must have exactly the state-lock and deny-user-data inline policies."
  }

  assert {
    condition     = one(jsondecode(aws_iam_role_policy.ci_plan_state_lock.policy).Statement).Resource == "arn:aws:s3:::talktally-tfstate-3af2cc3e/envs/*.tflock"
    error_message = "The plan role may write only lock files of the environment stacks."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_plan_deny_user_data.policy).Statement : s
      if s.Sid == "DenyBootstrapStateReads" && s.Effect == "Deny" && contains(s.Action, "s3:GetObject")
    ]).Resource == "arn:aws:s3:::talktally-tfstate-3af2cc3e/bootstrap/*"
    error_message = "The plan role must not read the bootstrap state, which holds the alert email address."
  }

  assert {
    condition     = toset(one(jsondecode(aws_iam_role_policy.ci_plan_state_lock.policy).Statement).Action) == toset(["s3:PutObject", "s3:DeleteObject"])
    error_message = "The plan role may only put and delete lock files."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_plan_deny_user_data.policy).Statement : s
      if s.Sid == "DenyObjectsOutsideStateBucket" && s.Effect == "Deny" && contains(s.Action, "s3:GetObject")
    ]).NotResource == "arn:aws:s3:::talktally-tfstate-3af2cc3e/*"
    error_message = "The plan role must not read S3 objects outside the state bucket."
  }

  assert {
    condition = length(setsubtract(
      [
        "cognito-idp:ListUsers",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "sqs:ReceiveMessage",
        "states:GetExecutionHistory",
        "transcribe:GetTranscriptionJob",
        "xray:BatchGetTraces",
      ],
      one([
        for s in jsondecode(aws_iam_role_policy.ci_plan_deny_user_data.policy).Statement : s.Action
        if s.Sid == "DenyUserDataReads" && s.Effect == "Deny" && s.Resource == "*"
      ]),
    )) == 0
    error_message = "The plan role must not read user records, items, logs or execution history."
  }

  assert {
    condition = length(setsubtract(
      [
        "account:GetAlternateContact",
        "account:GetContactInformation",
        "account:GetPrimaryEmail",
        "cloudtrail:GetQueryResults",
        "cloudtrail:LookupEvents",
        "sns:ListSubscriptions",
        "sns:ListSubscriptionsByTopic",
      ],
      one([
        for s in jsondecode(aws_iam_role_policy.ci_plan_deny_user_data.policy).Statement : s.Action
        if s.Sid == "DenyOwnerContactReads" && s.Effect == "Deny" && s.Resource == "*"
      ]),
    )) == 0
    error_message = "The plan role must not read the owner's contact details or the alert subscriptions."
  }
}

run "deploy_role_manages_only_bounded_workload_roles" {
  command = plan

  assert {
    condition     = toset(aws_iam_role_policy_attachments_exclusive.ci_deploy.policy_arns) == toset(["arn:aws:iam::aws:policy/PowerUserAccess"])
    error_message = "The deploy role must have exactly the PowerUserAccess managed policy."
  }

  assert {
    condition     = toset(aws_iam_role_policies_exclusive.ci_deploy.policy_names) == toset(["workload-iam", "bootstrap-guards"])
    error_message = "The deploy role must have exactly the workload-iam and bootstrap-guards inline policies."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_workload_iam.policy).Statement : s
      if s.Sid == "ManageWorkloadRolesWithBoundary"
    ]).Condition.StringEquals["iam:PermissionsBoundary"] == aws_iam_policy.workload_boundary.arn
    error_message = "Creating or changing a workload role must require the workload boundary."
  }

  assert {
    condition = length(setsubtract(
      ["iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy", "iam:PutRolePermissionsBoundary", "iam:UpdateAssumeRolePolicy"],
      one([
        for s in jsondecode(aws_iam_role_policy.ci_deploy_workload_iam.policy).Statement : s.Action
        if s.Sid == "ManageWorkloadRolesWithBoundary"
      ]),
    )) == 0
    error_message = "Every role write that grants permissions must be under the boundary condition."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_workload_iam.policy).Statement :
      alltrue([
        for r in s.Resource : can(regex("^arn:aws:iam::123456789012:(role|policy)/talktally-(dev|prod)-\\*$", r))
      ])
      if s.Effect == "Allow" && s.Sid != "ReadIam"
    ])
    error_message = "IAM writes must be limited to talktally-dev-* and talktally-prod-* roles and policies, never the CI roles."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_workload_iam.policy).Statement : s
      if s.Sid == "ReadIam"
    ]).Action == ["iam:Get*", "iam:List*"]
    error_message = "The only IAM statement on all resources must be read-only."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_workload_iam.policy).Statement : s
      if s.Sid == "KeepBoundaries"
    ]) == { Sid = "KeepBoundaries", Effect = "Deny", Action = "iam:DeleteRolePermissionsBoundary", Resource = "*" }
    error_message = "Removing a permissions boundary must be denied."
  }
}

run "boundary_and_guards_protect_identity_billing_and_bootstrap" {
  command = plan

  assert {
    condition = one([
      for s in jsondecode(aws_iam_policy.workload_boundary.policy).Statement : s.NotAction
      if s.Effect == "Allow"
    ]) == ["iam:*", "organizations:*", "account:*"]
    error_message = "The boundary must allow everything except IAM, Organizations and account actions."
  }

  assert {
    condition = jsonencode(jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement) == jsonencode([
      for s in jsondecode(aws_iam_policy.workload_boundary.policy).Statement : s
      if s.Effect == "Deny"
    ])
    error_message = "The deploy role and the boundary must deny the same things, so created roles cannot get around the guards."
  }

  assert {
    condition = length(setsubtract(
      ["account:*", "budgets:*", "ce:*", "freetier:*", "payments:*", "sso:*"],
      one([
        for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s.Action
        if s.Sid == "DenyAccountBillingAndCost" && s.Resource == "*"
      ]),
    )) == 0
    error_message = "The guards must deny account, budgets, cost, Free Tier plan, payment and Identity Center actions."
  }

  # one() fails when a guard is missing, so deleting a guard fails the test.
  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s
      if s.Sid == "DenyStateBucketChanges"
    ]).Resource == "arn:aws:s3:::talktally-tfstate-3af2cc3e"
    error_message = "The guards must cover the state bucket."
  }

  assert {
    condition = length(setsubtract(
      ["s3:DeleteBucket", "s3:PutBucketPolicy", "s3:PutBucketVersioning", "s3:PutReplicationConfiguration"],
      one([
        for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s.Action
        if s.Sid == "DenyStateBucketChanges"
      ]),
    )) == 0
    error_message = "The guards must protect the state bucket configuration, including replication."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s
      if s.Sid == "DenyStateHistoryDeletion"
      ]) == {
      Sid      = "DenyStateHistoryDeletion"
      Effect   = "Deny"
      Action   = "s3:DeleteObjectVersion"
      Resource = "arn:aws:s3:::talktally-tfstate-3af2cc3e/*"
    }
    error_message = "The guards must keep old state versions."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s
      if s.Sid == "DenyAlertsTopicChanges"
    ]).Resource == aws_sns_topic.alerts.arn
    error_message = "The guards must cover the alerts topic."
  }

  assert {
    condition = length(setsubtract(
      ["sns:DeleteTopic", "sns:SetSubscriptionAttributes", "sns:SetTopicAttributes", "sns:Subscribe"],
      one([
        for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s.Action
        if s.Sid == "DenyAlertsTopicChanges"
      ]),
    )) == 0
    error_message = "The guards must protect the alerts topic and its subscriptions."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s
      if s.Sid == "DenyBootstrapStateAccess"
    ]).Resource == "arn:aws:s3:::talktally-tfstate-3af2cc3e/bootstrap/*"
    error_message = "The guards must cover the bootstrap state."
  }

  assert {
    condition = length(setsubtract(
      ["s3:GetObject", "s3:GetObjectVersionForReplication", "s3:PutObject", "s3:DeleteObject", "s3:ReplicateObject"],
      one([
        for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s.Action
        if s.Sid == "DenyBootstrapStateAccess"
      ]),
    )) == 0
    error_message = "CI must not read, write, delete or replicate into the bootstrap state."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s
      if s.Sid == "DenyParentDnsZoneAccess"
      ]) == {
      Sid      = "DenyParentDnsZoneAccess"
      Effect   = "Deny"
      Action   = "route53:*"
      Resource = "arn:aws:route53:::hostedzone/ZPARENT0000000000000"
    }
    error_message = "CI must not touch the tybu.me zone at all."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s
      if s.Sid == "DenyDnsZoneDeletionAndDnssec"
    ]).Resource == aws_route53_zone.app.arn
    error_message = "The guards must cover the app DNS zone."
  }

  assert {
    condition = length(setsubtract(
      ["route53:DeleteHostedZone", "route53:DisableHostedZoneDNSSEC", "route53:EnableHostedZoneDNSSEC", "route53:CreateKeySigningKey"],
      one([
        for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s.Action
        if s.Sid == "DenyDnsZoneDeletionAndDnssec"
      ]),
    )) == 0
    error_message = "CI must not delete the app DNS zone or change its DNSSEC settings."
  }

  assert {
    condition = one([
      for s in jsondecode(aws_iam_role_policy.ci_deploy_bootstrap_guards.policy).Statement : s
      if s.Sid == "DenyDnsDelegationRecordChanges"
      ]) == {
      Sid       = "DenyDnsDelegationRecordChanges"
      Effect    = "Deny"
      Action    = "route53:ChangeResourceRecordSets"
      Resource  = "arn:aws:route53:::hostedzone/ZAPP00000000000000000"
      Condition = { "ForAnyValue:StringEquals" = { "route53:ChangeResourceRecordSetsRecordTypes" = ["NS", "SOA"] } }
    }
    error_message = "CI must not change NS or SOA records, even in a request with other record types."
  }

  # IAM quota for customer managed policies. jsonencode writes no whitespace,
  # so the length of the string is the size that IAM counts.
  assert {
    condition     = length(aws_iam_policy.workload_boundary.policy) <= 6144
    error_message = "The workload boundary must stay within the 6,144-character limit of a managed policy."
  }
}

run "rejects_an_invalid_alert_email" {
  command = plan

  variables {
    alert_email = "not-an-email"
  }

  expect_failures = [var.alert_email]
}

# GitHub Actions reach AWS through OIDC, with no stored keys (ADR-0003,
# ADR-0027). Pull request jobs assume the read-only plan role. Jobs in the dev
# and prod GitHub environments assume the deploy role.

locals {
  github_oidc_host = "token.actions.githubusercontent.com"

  # Immutable OIDC subject prefix of this repository: owner and repository
  # names with their IDs, GitHub's format for repositories created after
  # 2026-07-15. A recycled owner or repository name cannot produce it. Source:
  # GET /repos/tybuszesDev/talktally/actions/oidc/customization/sub
  github_subject_prefix = "repo:tybuszesDev@58275357/talktally@1447250076"

  # GitHub environments whose jobs may deploy. Their protection rules limit
  # them to main (and release tags for prod); see README.md.
  deploy_environments = ["dev", "prod"]

  # IAM roles and policies of the environment stacks use the prefix
  # talktally-<env>- (ADR-0003). The CI roles (talktally-ci-*) do not match.
  workload_role_arns = [
    for env in local.deploy_environments : "arn:aws:iam::${local.account_id}:role/talktally-${env}-*"
  ]
  workload_policy_arns = [
    for env in local.deploy_environments : "arn:aws:iam::${local.account_id}:policy/talktally-${env}-*"
  ]

  # Denied to the deploy role and, through the permissions boundary, to every
  # role it creates, so the deploy role cannot get around them.
  bootstrap_guard_statements = [
    {
      # Includes Free Tier plan changes, payments and Identity Center (ADR-0026),
      # and the account contact details (name, address, phone, root email).
      Sid    = "DenyAccountBillingAndCost"
      Effect = "Deny"
      Action = [
        "account:*",
        "aws-portal:*",
        "billing:*",
        "budgets:*",
        "ce:*",
        "consolidatedbilling:*",
        "cur:*",
        "freetier:*",
        "identitystore:*",
        "invoicing:*",
        "payments:*",
        "purchase-orders:*",
        "sso:*",
        "tax:*",
      ]
      Resource = "*"
    },
    {
      Sid    = "DenyStateBucketChanges"
      Effect = "Deny"
      Action = [
        "s3:DeleteBucket",
        "s3:DeleteBucketPolicy",
        "s3:PutBucketAcl",
        "s3:PutBucketOwnershipControls",
        "s3:PutBucketPolicy",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration",
        "s3:PutReplicationConfiguration",
      ]
      Resource = aws_s3_bucket.state.arn
    },
    {
      # Old state versions are the way back from a broken state.
      Sid      = "DenyStateHistoryDeletion"
      Effect   = "Deny"
      Action   = "s3:DeleteObjectVersion"
      Resource = "${aws_s3_bucket.state.arn}/*"
    },
    {
      # CI never touches the bootstrap state. A changed state could name a
      # foreign provider, which the owner's next local init would install and
      # plan would run with administrator credentials.
      Sid    = "DenyBootstrapStateAccess"
      Effect = "Deny"
      Action = [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetObjectVersionForReplication",
        "s3:PutObject",
        "s3:ReplicateDelete",
        "s3:ReplicateObject",
        "s3:RestoreObject",
      ]
      Resource = "${aws_s3_bucket.state.arn}/bootstrap/*"
    },
    {
      # Subscription changes include filter policies that would silently drop
      # the owner's alerts.
      Sid    = "DenyAlertsTopicChanges"
      Effect = "Deny"
      Action = [
        "sns:AddPermission",
        "sns:ConfirmSubscription",
        "sns:DeleteTopic",
        "sns:PutDataProtectionPolicy",
        "sns:RemovePermission",
        "sns:SetSubscriptionAttributes",
        "sns:SetTopicAttributes",
        "sns:Subscribe",
        "sns:Unsubscribe",
      ]
      Resource = aws_sns_topic.alerts.arn
    },
  ]
}

# For GitHub, AWS checks the certificate against its own trusted root CAs, so
# no thumbprint is set.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.github_oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# ---------------------------------------------------------------------------
# Plan role: pull request jobs run terraform plan.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ci_plan" {
  name        = "talktally-ci-plan"
  description = "GitHub Actions pull request jobs: read-only terraform plan (ADR-0027)."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "GitHubPullRequests"
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.github_oidc_host}:aud" = "sts.amazonaws.com"
            "${local.github_oidc_host}:sub" = "${local.github_subject_prefix}:pull_request"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachments_exclusive" "ci_plan" {
  role_name   = aws_iam_role.ci_plan.name
  policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}

# terraform plan takes the S3 state lock (use_lockfile), so the role may write
# and delete the lock files of the environment stacks, and nothing else.
resource "aws_iam_role_policy" "ci_plan_state_lock" {
  name = "state-lock"
  role = aws_iam_role.ci_plan.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteEnvironmentStateLockFiles"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.state.arn}/envs/*.tflock"
      },
    ]
  })
}

# ReadOnlyAccess can also read user data. Pull request jobs may run code from
# dependency updates, so these reads are denied.
resource "aws_iam_role_policy" "ci_plan_deny_user_data" {
  name = "deny-user-data"
  role = aws_iam_role.ci_plan.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Recordings and transcripts; the state files stay readable.
        Sid         = "DenyObjectsOutsideStateBucket"
        Effect      = "Deny"
        Action      = ["s3:GetObject", "s3:GetObjectVersion"]
        NotResource = "${aws_s3_bucket.state.arn}/*"
      },
      {
        # The bootstrap state holds the owner's alert email address. The
        # environment stacks read bootstrap values through data sources.
        Sid      = "DenyBootstrapStateReads"
        Effect   = "Deny"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.state.arn}/bootstrap/*"
      },
      {
        # Other ways to the owner's contact details: subscription endpoints
        # (the alert email) and the account contact information.
        Sid    = "DenyOwnerContactReads"
        Effect = "Deny"
        Action = [
          "account:GetAlternateContact",
          "account:GetContactInformation",
          "account:GetPrimaryEmail",
          "sns:ListSubscriptions",
          "sns:ListSubscriptionsByTopic",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyUserDataReads"
        Effect = "Deny"
        Action = [
          "cognito-idp:AdminGetDevice",
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminListDevices",
          "cognito-idp:AdminListUserAuthEvents",
          "cognito-idp:ListUsers",
          "cognito-idp:ListUsersInGroup",
          "dynamodb:BatchGetItem",
          "dynamodb:GetItem",
          "dynamodb:GetRecords",
          "dynamodb:PartiQLSelect",
          "dynamodb:Query",
          "dynamodb:Scan",
          "logs:FilterLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogRecord",
          "logs:GetQueryResults",
          "logs:StartLiveTail",
          "logs:StartQuery",
          "sqs:ReceiveMessage",
          "states:DescribeExecution",
          "states:GetExecutionHistory",
          "transcribe:GetTranscriptionJob",
          "xray:BatchGetTraces",
          "xray:GetTraceSummaries",
        ]
        Resource = "*"
      },
    ]
  })
}

# Removes inline policies added outside Terraform on the next apply.
resource "aws_iam_role_policies_exclusive" "ci_plan" {
  role_name = aws_iam_role.ci_plan.name
  policy_names = [
    aws_iam_role_policy.ci_plan_state_lock.name,
    aws_iam_role_policy.ci_plan_deny_user_data.name,
  ]
}

# ---------------------------------------------------------------------------
# Deploy role: jobs in the dev and prod environments run terraform apply.
# ---------------------------------------------------------------------------

# Maximum permissions of every role the deploy role creates: no IAM, no
# Organizations, no account settings, and the bootstrap guards.
resource "aws_iam_policy" "workload_boundary" {
  name        = "talktally-workload-boundary"
  description = "Permissions boundary for roles created by the deploy role (ADR-0027)."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "AllowAllButIdentityAndAccount"
          Effect    = "Allow"
          NotAction = ["iam:*", "organizations:*", "account:*"]
          Resource  = "*"
        },
      ],
      local.bootstrap_guard_statements,
    )
  })
}

resource "aws_iam_role" "ci_deploy" {
  name        = "talktally-ci-deploy"
  description = "GitHub Actions jobs in the dev and prod environments: terraform apply (ADR-0027)."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "GitHubDeployEnvironments"
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.github_oidc_host}:aud" = "sts.amazonaws.com"
            "${local.github_oidc_host}:sub" = [
              for env in local.deploy_environments : "${local.github_subject_prefix}:environment:${env}"
            ]
          }
        }
      },
    ]
  })
}

# Everything except IAM, Organizations and account settings.
resource "aws_iam_role_policy_attachments_exclusive" "ci_deploy" {
  role_name   = aws_iam_role.ci_deploy.name
  policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
}

resource "aws_iam_role_policy" "ci_deploy_workload_iam" {
  name = "workload-iam"
  role = aws_iam_role.ci_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadIam"
        Effect   = "Allow"
        Action   = ["iam:Get*", "iam:List*"]
        Resource = "*"
      },
      {
        # Each action applies only to a role that carries the boundary, and a
        # new role must get it when it is created.
        Sid    = "ManageWorkloadRolesWithBoundary"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePermissionsBoundary",
          "iam:PutRolePolicy",
          "iam:UpdateAssumeRolePolicy",
          "iam:UpdateRole",
          "iam:UpdateRoleDescription",
        ]
        Resource = local.workload_role_arns
        Condition = {
          StringEquals = {
            "iam:PermissionsBoundary" = aws_iam_policy.workload_boundary.arn
          }
        }
      },
      {
        # These actions do not support the iam:PermissionsBoundary condition.
        Sid      = "TagAndPassWorkloadRoles"
        Effect   = "Allow"
        Action   = ["iam:PassRole", "iam:TagRole", "iam:UntagRole"]
        Resource = local.workload_role_arns
      },
      {
        Sid    = "ManageWorkloadPolicies"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicy",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy",
        ]
        Resource = local.workload_policy_arns
      },
      {
        Sid      = "KeepBoundaries"
        Effect   = "Deny"
        Action   = "iam:DeleteRolePermissionsBoundary"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "ci_deploy_bootstrap_guards" {
  name = "bootstrap-guards"
  role = aws_iam_role.ci_deploy.name

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.bootstrap_guard_statements
  })
}

resource "aws_iam_role_policies_exclusive" "ci_deploy" {
  role_name = aws_iam_role.ci_deploy.name
  policy_names = [
    aws_iam_role_policy.ci_deploy_workload_iam.name,
    aws_iam_role_policy.ci_deploy_bootstrap_guards.name,
  ]
}

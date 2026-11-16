# Sign-in for the web and mobile apps (ADR-0004, settings from ADR-0032).
# Essentials tier: free up to 10,000 monthly active users.

locals {
  temporary_password_days = 7
}

# The user pool holds the accounts. Its `sub` is the owner ID of all data in
# DynamoDB, so a new pool would orphan every user's data: deletion protection
# stays on, and settings that force a new pool (such as username_attributes)
# must not change.
resource "aws_cognito_user_pool" "users" {
  name           = "${local.name_prefix}users"
  user_pool_tier = "ESSENTIALS"

  deletion_protection = "ACTIVE"

  # Users sign in with their email address; there is no separate username.
  username_attributes = ["email"]
  username_configuration {
    case_sensitive = false
  }

  # Cognito sends a code to confirm a new email, and the old address stays in
  # use until the user enters it.
  auto_verified_attributes = ["email"]
  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  # Invite-only: no self sign-up. `pnpm invite <email>` creates users.
  admin_create_user_config {
    allow_admin_create_user_only = true

    invite_message_template {
      email_subject = "Your invitation to TalkTally"
      email_message = <<-EOT
        <p>You have been invited to TalkTally.</p>
        <p>Sign in with your email address and this temporary password: <strong>{####}</strong></p>
        <p>You will choose your own password when you first sign in. The temporary password expires in ${local.temporary_password_days} days.</p>
        <p>Account: {username}</p>
      EOT
      # Never sent (invitations go by email), but CreateUserPool rejects an
      # empty SMS template, which the provider sends when this is unset.
      sms_message = "TalkTally account {username}, temporary password {####}"
    }
  }

  # NIST SP 800-63B Rev. 4: at least 15 characters, no composition rules.
  password_policy {
    minimum_length                   = 15
    require_lowercase                = false
    require_uppercase                = false
    require_numbers                  = false
    require_symbols                  = false
    temporary_password_validity_days = local.temporary_password_days
  }

  # Optional authenticator-app codes (TOTP). No SMS: it costs per message and
  # needs an SNS role.
  mfa_configuration = "OPTIONAL"
  software_token_mfa_configuration {
    enabled = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Sender no-reply@verificationemail.com, at most 50 emails a day for the
  # whole account. An SES sender on talktally.tybu.me replaces it before the
  # public demo or prod (ADR-0032).
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
}

# Public app clients: no secret, because a secret cannot be kept in a browser
# or an app bundle. Only SRP sign-in and token refresh, with no OAuth flows or
# callback URLs, because the apps have their own sign-in screens (ADR-0004).
locals {
  app_clients = {
    # Also used by the desktop app later.
    web = { refresh_token_days = 30 }
    # Tokens are kept in secure storage on the phone.
    mobile = { refresh_token_days = 90 }
  }
}

resource "aws_cognito_user_pool_client" "app" {
  for_each = local.app_clients

  name         = "${local.name_prefix}${each.key}"
  user_pool_id = aws_cognito_user_pool.users.id

  generate_secret     = false
  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  # Without OAuth, callback URLs and scopes cannot be set either.
  allowed_oauth_flows_user_pool_client = false

  # Sign-in and password recovery do not reveal whether an email has an account.
  prevent_user_existence_errors = "ENABLED"
  # Sign-out can revoke the refresh token.
  enable_token_revocation = true

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = each.value.refresh_token_days
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

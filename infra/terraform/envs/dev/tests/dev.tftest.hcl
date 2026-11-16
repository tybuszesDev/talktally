# Unit tests for the dev root module. The AWS provider is mocked, so nothing is
# created in AWS and no credentials are needed.
# Run: terraform -chdir=infra/terraform/envs/dev init -backend=false
#      terraform -chdir=infra/terraform/envs/dev test

mock_provider "aws" {}

run "names_use_the_environment_prefix" {
  command = plan

  assert {
    condition     = local.name_prefix == "talktally-dev-"
    error_message = "Resource names in dev must start with talktally-dev-."
  }

  assert {
    condition     = aws_resourcegroups_group.environment.name == "talktally-dev-resources"
    error_message = "The resource group must be named talktally-dev-resources."
  }
}

run "resource_group_selects_only_this_environment" {
  command = plan

  assert {
    condition = jsondecode(aws_resourcegroups_group.environment.resource_query[0].query) == {
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        { Key = "Project", Values = ["talktally"] },
        { Key = "Environment", Values = ["dev"] },
      ]
    }
    error_message = "The resource group must select all resources tagged Project=talktally and Environment=dev."
  }
}

# AWS checks the description only when it creates the group, so plan cannot
# catch it (#93). Pattern from the CreateGroup error message.
run "resource_group_description_uses_allowed_characters" {
  command = plan

  assert {
    condition     = can(regex("^[\\sa-zA-Z0-9_.-]*$", aws_resourcegroups_group.environment.description))
    error_message = "The resource group description may contain only letters, digits, spaces, '_', '.' and '-'."
  }
}

# User pool settings from ADR-0032. A changed value here is a decision to
# record first; some (username_attributes) would replace the pool and give
# every user a new sub.
run "user_pool_is_invite_only_with_email_sign_in" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool.users.name == "talktally-dev-users"
    error_message = "The user pool must be named talktally-dev-users."
  }

  assert {
    condition     = aws_cognito_user_pool.users.user_pool_tier == "ESSENTIALS"
    error_message = "The user pool must use the Essentials tier (ADR-0004)."
  }

  assert {
    condition     = aws_cognito_user_pool.users.admin_create_user_config[0].allow_admin_create_user_only
    error_message = "Self sign-up must be disabled: only administrators create users."
  }

  assert {
    condition     = aws_cognito_user_pool.users.deletion_protection == "ACTIVE"
    error_message = "Deletion protection must stay active: a new pool orphans every user's data."
  }

  assert {
    condition     = aws_cognito_user_pool.users.username_attributes == toset(["email"]) && !aws_cognito_user_pool.users.username_configuration[0].case_sensitive
    error_message = "Users must sign in with their email address, case-insensitive."
  }

  assert {
    condition     = aws_cognito_user_pool.users.user_attribute_update_settings[0].attributes_require_verification_before_update == toset(["email"])
    error_message = "A changed email must be verified before it replaces the old one."
  }
}

run "user_pool_sends_invitations_by_cognito_email" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool.users.email_configuration[0].email_sending_account == "COGNITO_DEFAULT"
    error_message = "Email must be sent by Cognito's default email until the SES sender exists (ADR-0032)."
  }

  # Cognito does not deliver an invitation whose template lacks a placeholder.
  assert {
    condition = alltrue([
      for placeholder in ["{username}", "{####}"] :
      strcontains(aws_cognito_user_pool.users.admin_create_user_config[0].invite_message_template[0].email_message, placeholder)
    ])
    error_message = "The invitation email must contain {username} and {####}."
  }

  assert {
    condition     = strcontains(aws_cognito_user_pool.users.admin_create_user_config[0].invite_message_template[0].email_message, "expires in ${aws_cognito_user_pool.users.password_policy[0].temporary_password_validity_days} days")
    error_message = "The invitation email must state the validity of the temporary password from the password policy."
  }
}

run "user_pool_password_and_mfa_settings" {
  command = plan

  assert {
    condition = (
      aws_cognito_user_pool.users.password_policy[0].minimum_length == 15
      && !aws_cognito_user_pool.users.password_policy[0].require_lowercase
      && !aws_cognito_user_pool.users.password_policy[0].require_uppercase
      && !aws_cognito_user_pool.users.password_policy[0].require_numbers
      && !aws_cognito_user_pool.users.password_policy[0].require_symbols
    )
    error_message = "Passwords must have at least 15 characters and no composition rules (NIST SP 800-63B Rev. 4)."
  }

  assert {
    condition     = aws_cognito_user_pool.users.password_policy[0].temporary_password_validity_days == 7
    error_message = "Temporary passwords must be valid for 7 days."
  }

  assert {
    condition     = aws_cognito_user_pool.users.mfa_configuration == "OPTIONAL" && aws_cognito_user_pool.users.software_token_mfa_configuration[0].enabled
    error_message = "MFA must be optional, with TOTP enabled."
  }

  assert {
    condition     = length(aws_cognito_user_pool.users.sms_configuration) == 0
    error_message = "SMS must not be configured: no SMS MFA or SMS messages."
  }

  assert {
    condition     = [for mechanism in aws_cognito_user_pool.users.account_recovery_setting[0].recovery_mechanism : mechanism.name] == ["verified_email"]
    error_message = "Account recovery must use only the verified email."
  }
}

run "app_clients_are_public_and_use_srp_only" {
  command = plan

  assert {
    condition     = keys(aws_cognito_user_pool_client.app) == ["mobile", "web"]
    error_message = "There must be exactly two app clients: web and mobile."
  }

  assert {
    condition = alltrue([
      for key, client in aws_cognito_user_pool_client.app : client.name == "talktally-dev-${key}"
    ])
    error_message = "App clients must be named talktally-dev-web and talktally-dev-mobile."
  }

  assert {
    condition     = alltrue([for client in aws_cognito_user_pool_client.app : client.generate_secret == false])
    error_message = "App clients must be public: no client secret."
  }

  assert {
    condition = alltrue([
      for client in aws_cognito_user_pool_client.app :
      toset(client.explicit_auth_flows) == toset(["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"])
    ])
    error_message = "App clients must allow only SRP sign-in and token refresh."
  }

  # Callback URLs and OAuth scopes need this flag, so it covers them too.
  assert {
    condition     = alltrue([for client in aws_cognito_user_pool_client.app : client.allowed_oauth_flows_user_pool_client == false])
    error_message = "App clients must not use OAuth flows (no hosted login page)."
  }

  assert {
    condition = alltrue([
      for client in aws_cognito_user_pool_client.app :
      client.prevent_user_existence_errors == "ENABLED" && client.enable_token_revocation
    ])
    error_message = "App clients must hide whether a user exists and allow token revocation."
  }
}

run "app_client_token_lifetimes" {
  command = plan

  assert {
    condition = alltrue([
      for client in aws_cognito_user_pool_client.app :
      client.access_token_validity == 60 && client.id_token_validity == 60
      && client.token_validity_units[0].access_token == "minutes"
      && client.token_validity_units[0].id_token == "minutes"
      && client.token_validity_units[0].refresh_token == "days"
    ])
    error_message = "Access and ID tokens must be valid for 60 minutes."
  }

  assert {
    condition     = aws_cognito_user_pool_client.app["web"].refresh_token_validity == 30
    error_message = "Web refresh tokens must be valid for 30 days."
  }

  assert {
    condition     = aws_cognito_user_pool_client.app["mobile"].refresh_token_validity == 90
    error_message = "Mobile refresh tokens must be valid for 90 days."
  }
}

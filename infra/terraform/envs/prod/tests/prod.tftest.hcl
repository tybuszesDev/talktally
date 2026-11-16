# Unit tests for the prod root module. The AWS provider is mocked, so nothing
# is created in AWS and no credentials are needed.
# Run: terraform -chdir=infra/terraform/envs/prod init -backend=false
#      terraform -chdir=infra/terraform/envs/prod test

mock_provider "aws" {}

run "names_use_the_environment_prefix" {
  command = plan

  assert {
    condition     = local.name_prefix == "talktally-prod-"
    error_message = "Resource names in prod must start with talktally-prod-."
  }

  assert {
    condition     = aws_resourcegroups_group.environment.name == "talktally-prod-resources"
    error_message = "The resource group must be named talktally-prod-resources."
  }
}

run "resource_group_selects_only_this_environment" {
  command = plan

  assert {
    condition = jsondecode(aws_resourcegroups_group.environment.resource_query[0].query) == {
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        { Key = "Project", Values = ["talktally"] },
        { Key = "Environment", Values = ["prod"] },
      ]
    }
    error_message = "The resource group must select all resources tagged Project=talktally and Environment=prod."
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

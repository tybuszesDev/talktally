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

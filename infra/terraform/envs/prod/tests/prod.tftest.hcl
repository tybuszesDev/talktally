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

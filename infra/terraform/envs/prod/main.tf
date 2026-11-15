locals {
  environment = "prod"

  # Every resource name starts with this prefix (ADR-0003). For IAM roles and
  # policies it is required: the deploy role may manage only those named
  # talktally-dev-* or talktally-prod-* (ADR-0027).
  name_prefix = "talktally-${local.environment}-"
}

# Lists every resource of this environment in the AWS console (Resource
# Groups), selected by the tags that default_tags sets in providers.tf. Tag
# filters with different keys must all match, so the group never shows
# another environment. Resource Groups has no charge.
resource "aws_resourcegroups_group" "environment" {
  name        = "${local.name_prefix}resources"
  description = "All TalkTally ${local.environment} resources, selected by tag."

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        { Key = "Project", Values = ["talktally"] },
        { Key = "Environment", Values = [local.environment] },
      ]
    })
  }
}

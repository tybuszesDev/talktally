# Credentials come from the environment: in CI the plan or deploy role
# (ADR-0027), locally AWS_PROFILE=talktally-admin after `aws login`
# (ADR-0026). No profile or keys are set here.
provider "aws" {
  region = "eu-central-1"

  # Every resource of this stack gets these tags. tflint
  # (aws_resource_missing_tags) fails a resource that would end up without
  # them, and the resource group in main.tf selects resources by them.
  default_tags {
    tags = {
      Project     = "talktally"
      Environment = local.environment
      ManagedBy   = "terraform"
    }
  }
}

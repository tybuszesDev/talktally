# Credentials come from the environment: locally AWS_PROFILE=talktally-admin
# after `aws login` (ADR-0026). No profile or keys are set here.
provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Project     = "talktally"
      Environment = "shared"
      ManagedBy   = "terraform"
    }
  }
}

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72"
    }
  }

  # State lives in the bucket that this stack creates (state.tf). The first
  # apply on a new account uses a temporary local backend; see README.md.
  # Backend blocks cannot use variables, so the bucket name is repeated here.
  backend "s3" {
    bucket       = "talktally-tfstate-3af2cc3e"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

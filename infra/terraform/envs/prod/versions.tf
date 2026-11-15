terraform {
  # Same minimum as the bootstrap stack: 1.15 is the first version whose S3
  # backend accepts `aws login` credentials (ADR-0026). CI installs the exact
  # version set in .github/workflows/terraform.yml.
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72"
    }
  }

  # State lives in the bucket of the bootstrap stack. The key starts with
  # envs/, the only prefix whose lock files the plan role may write
  # (ADR-0027). Backend blocks cannot use variables, so the values are
  # repeated here.
  backend "s3" {
    bucket       = "talktally-tfstate-3af2cc3e"
    key          = "envs/prod/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

# TFLint configuration for every Terraform root module under infra/terraform
# (ADR-0003, ADR-0017). Run it from this directory; in recursive mode the
# config path must be absolute:
#   tflint --init --recursive --config "$(pwd)/.tflint.hcl"
#   tflint --recursive --config "$(pwd)/.tflint.hcl"
# Renovate updates the plugin version below.

# Terraform language rules, bundled with TFLint: deprecated syntax, unused
# declarations, missing version constraints.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS rules: invalid values that `terraform validate` cannot see, such as
# unknown instance types. TFLint checks the plugin's signature on --init.
plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Every taggable resource carries these tags. The rule counts the provider's
# default_tags, so the root modules set them once in providers.tf.
rule "aws_resource_missing_tags" {
  enabled = true
  tags    = ["Project", "Environment", "ManagedBy"]
}

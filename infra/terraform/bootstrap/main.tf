# The account ID is read at run time, so it never appears in the repository
# (ADR-0012).
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Must match the bucket in the backend block in versions.tf. The random
  # suffix makes the name globally unique without the account ID.
  state_bucket_name = "talktally-tfstate-3af2cc3e"
}

# S3 bucket for Terraform state of every root module (bootstrap, envs/dev,
# envs/prod), each under its own key. Locking uses S3 lock files
# (use_lockfile), so no DynamoDB table is needed (ADR-0003).
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  # Losing this bucket means losing track of all infrastructure.
  lifecycle {
    prevent_destroy = true
  }
}

# Every state write keeps the previous version, so a broken state can be
# restored.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AWS-managed keys, no cost), as in SECURITY-MODEL.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLs are disabled; only IAM and the bucket policy control access.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Reject every request that does not use TLS.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        # State is read and written only through the bucket itself. Requests
        # through an access point are authorized against the access point ARN,
        # where the CI roles' denies on bucket ARNs might not apply (ADR-0027).
        Sid       = "DenyAccessPointRequests"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*",
        ]
        Condition = {
          Null = {
            "s3:DataAccessPointArn" = "false"
          }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# Old state versions expire after 90 days, but the 10 newest are always kept.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    # An empty filter applies the rule to every object.
    filter {}

    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 10
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # The provider documentation requires versioning to be enabled first.
  depends_on = [aws_s3_bucket_versioning.state]
}

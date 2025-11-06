# infra/terraform/ecr_s3_audit.tf

# We already have these things in the account, so we READ them instead of creating.

data "aws_caller_identity" "me" {}

# existing ECR repo "tasky"
data "aws_ecr_repository" "tasky" {
  name = "tasky"
}

# existing CloudTrail bucket "tasky-wiz-cloudtrail-<account>"
data "aws_s3_bucket" "cloudtrail" {
  bucket = "tasky-wiz-cloudtrail-${data.aws_caller_identity.me.account_id}"
}

# (no outputs here — outputs.tf already exports ecr_repo etc.)


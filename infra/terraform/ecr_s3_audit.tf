# we need the account id for names
data "aws_caller_identity" "me" {}

############################################################
# 1. ECR – repo already exists, so just read it
#    (Jenkins job was failing on "RepositoryAlreadyExists")
############################################################
data "aws_ecr_repository" "tasky" {
  name = "tasky"
}

# if you still want to surface it as an output
output "ecr_repo" {
  value = data.aws_ecr_repository.tasky.repository_url
}

############################################################
# 2. CloudTrail bucket – already created outside TF
#    so read it instead of creating it
############################################################
data "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.project}-cloudtrail-${data.aws_caller_identity.me.account_id}"
}

# optional: so other modules can reference it
output "cloudtrail_bucket_arn" {
  value = data.aws_s3_bucket.cloudtrail.arn
}

############################################################
# 3. GuardDuty – detector already exists
#    TF can't "discover and create-if-missing" nicely here,
#    so we STOP creating it in this module.
#
#    If you want to keep it in TF later, create a *separate*
#    stack just for GuardDuty, or switch to a backend that
#    keeps state between runs.
############################################################
# (intentionally removed aws_guardduty_detector.gd)


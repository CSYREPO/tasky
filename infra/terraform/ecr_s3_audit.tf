resource "aws_ecr_repository" "tasky" {
  name = var.ecr_repo_name
  image_scanning_configuration { scan_on_push = true }
}

resource "random_id" "sfx" { byte_length = 3 }

resource "aws_s3_bucket" "mongo_backups" { bucket = "${var.project}-mongo-backups-${random_id.sfx.hex}" }
resource "aws_s3_bucket_public_access_block" "mongo_backups" {
  bucket                  = aws_s3_bucket.mongo_backups.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "mongo_backups_public" {
  bucket = aws_s3_bucket.mongo_backups.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Sid = "List", Effect = "Allow", Principal = "*", Action = "s3:ListBucket", Resource = aws_s3_bucket.mongo_backups.arn },
      { Sid = "Get", Effect = "Allow", Principal = "*", Action = "s3:GetObject", Resource = "${aws_s3_bucket.mongo_backups.arn}/*" }
    ]
  })
}

data "aws_caller_identity" "me" {}
resource "aws_s3_bucket" "cloudtrail" { bucket = "${var.project}-cloudtrail-${data.aws_caller_identity.me.account_id}" }
resource "aws_cloudtrail" "main" {
  name                          = "${var.project}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
}
resource "aws_guardduty_detector" "gd" { enable = true }


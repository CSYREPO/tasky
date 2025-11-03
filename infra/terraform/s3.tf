##############################
# S3 for MongoDB backups
##############################

# make bucket name unique per account/project
resource "random_id" "mongo_backups_suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "mongo_backups" {
  bucket = "${var.project}-mongo-backups-${random_id.mongo_backups_suffix.hex}"

  tags = {
    Name        = "${var.project}-mongo-backups"
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = var.managed_by
  }
}

# optional but nice: keep versions of backups
resource "aws_s3_bucket_versioning" "mongo_backups" {
  bucket = aws_s3_bucket.mongo_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

# optional: block public access
resource "aws_s3_bucket_public_access_block" "mongo_backups" {
  bucket                  = aws_s3_bucket.mongo_backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


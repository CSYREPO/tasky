##############################################
# Root infrastructure for Tasky (no EKS yet)
##############################################

data "aws_caller_identity" "current" {}

# --- VPC ---
module "vpc" {
  source              = "./modules/vpc"
  project             = var.project
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  owner               = var.owner
}

# --- Jenkins EC2 ---
module "ec2_jenkins" {
  source         = "./modules/ec2"
  project        = var.project
  instance_name  = "jenkins"
  instance_type  = var.jenkins_instance_type
  subnet_id      = module.vpc.public_subnet_id
  key_pair_name  = var.key_pair_name
  owner          = var.owner
  user_data_type = "jenkins"
}

# --- Mongo EC2 (intentional weaknesses) ---
module "ec2_mongo" {
  source              = "./modules/ec2"
  project             = var.project
  instance_name       = "mongo"
  instance_type       = var.mongo_instance_type
  subnet_id           = module.vpc.public_subnet_id # public (SSH open)
  key_pair_name       = var.key_pair_name
  owner               = var.owner
  user_data_type      = "mongo"
  ami_id              = var.mongo_ami           # use your chosen AMI
  private_subnet_cidr = var.private_subnet_cidr # allow 27017 from private
  mongo_backup_bucket = var.mongo_backup_bucket
}

# --- ECR for Tasky image ---
resource "aws_ecr_repository" "tasky" {
  name = "tasky"
  image_scanning_configuration { scan_on_push = true }
  tags = { Project = var.project }
}

# =========================
# S3 (Mongo backups) - PUBLIC (intentional weakness)
# =========================

# 1) Backups bucket
resource "aws_s3_bucket" "mongo_backups" {
  bucket = var.mongo_backup_bucket
  tags   = { Project = var.project }
}

# 2) Versioning
resource "aws_s3_bucket_versioning" "mongo_backups" {
  bucket = aws_s3_bucket.mongo_backups.id
  versioning_configuration { status = "Enabled" }
}

# 3) Turn OFF bucket-level BPA so public policy will attach
resource "aws_s3_bucket_public_access_block" "mongo_bpa" {
  bucket                  = aws_s3_bucket.mongo_backups.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 4) Short wait for control-plane propagation
resource "time_sleep" "wait_after_bpa" {
  depends_on      = [aws_s3_bucket_public_access_block.mongo_bpa]
  create_duration = "20s"
}

# 5) PUBLIC read + list policy (intentional weakness)
resource "aws_s3_bucket_policy" "mongo_public" {
  bucket = aws_s3_bucket.mongo_backups.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "PublicReadList",
      Effect    = "Allow",
      Principal = "*",
      Action    = ["s3:GetObject", "s3:ListBucket"],
      Resource = [
        aws_s3_bucket.mongo_backups.arn,
        "${aws_s3_bucket.mongo_backups.arn}/*"
      ]
    }]
  })
  depends_on = [
    aws_s3_bucket_public_access_block.mongo_bpa,
    time_sleep.wait_after_bpa
  ]
}

# =========================
# CloudTrail (PRIVATE logs)
# =========================

# 1) Private bucket for CloudTrail logs
resource "aws_s3_bucket" "trail_logs" {
  bucket = "${var.project}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  tags   = { Project = var.project }
}

# 2) Versioning for trail logs bucket
resource "aws_s3_bucket_versioning" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id
  versioning_configuration { status = "Enabled" }
}

# 3) Bucket policy required by CloudTrail
resource "aws_s3_bucket_policy" "trail_policy" {
  bucket = aws_s3_bucket.trail_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck",
        Effect    = "Allow",
        Principal = { "Service" : "cloudtrail.amazonaws.com" },
        Action    = "s3:GetBucketAcl",
        Resource  = aws_s3_bucket.trail_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite",
        Effect    = "Allow",
        Principal = { "Service" : "cloudtrail.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.trail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = { "StringEquals" : { "s3:x-amz-acl" : "bucket-owner-full-control" } }
      }
    ]
  })
}

# 4) The CloudTrail itself
resource "aws_cloudtrail" "main" {
  name                          = "${var.project}-trail"
  s3_bucket_name                = aws_s3_bucket.trail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  tags                          = { Project = var.project }
}


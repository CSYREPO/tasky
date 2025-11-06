# ------------------------------------------------------------
# Security groups
# ------------------------------------------------------------

# Jenkins SG: SSH + Jenkins UI
resource "aws_security_group" "jenkins" {
  name        = "${var.project}-jenkins-sg"
  description = "Allow SSH and Jenkins UI"
  vpc_id      = aws_vpc.main.id

  # SSH from anywhere (tighten later)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins UI (controlled by variable)
  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.jenkins_allowed_cidrs
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-jenkins-sg"
    Environment = try(var.environment, "dev")
    Owner       = try(var.owner, "unknown")
    ManagedBy   = try(var.managed_by, "terraform")
  }
}

# Mongo SG: SSH + MongoDB exposed publicly (intentional weakness)
resource "aws_security_group" "mongo" {
  name        = "${var.project}-mongo-sg"
  description = "Allow SSH and MongoDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # intentional for exercise
  }

  ingress {
    description = "MongoDB"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # intentional weakness
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-mongo-sg"
    Environment = try(var.environment, "dev")
    Owner       = try(var.owner, "unknown")
    ManagedBy   = try(var.managed_by, "terraform")
  }
}

# ------------------------------------------------------------
# Inspector 2 - account-level enable
# ------------------------------------------------------------
# This turns on Inspector2 for EC2/ECR/Lambda in this account/region
resource "aws_inspector2_enabler" "this" {
  account_ids = ["self"]
  resource_types = [
    "EC2",
    "ECR",
    "LAMBDA",
  ]
}

# ------------------------------------------------------------
# VPC Flow Logs -> CloudWatch
# ------------------------------------------------------------

# CloudWatch log group to receive VPC flow logs
resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/aws/vpc/${var.project}/flows"
  retention_in_days = 30

  tags = {
    Project     = var.project
    Environment = try(var.environment, "dev")
    ManagedBy   = try(var.managed_by, "terraform")
  }
}

# Flow log for the main VPC (defined in network.tf as aws_vpc.main)
resource "aws_flow_log" "vpc" {
  log_destination_type = "cloud-watch-logs"
  log_group_name       = aws_cloudwatch_log_group.vpc_flow.name
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id

  # IAM role not needed because we use CW Logs as destination in same account

  tags = {
    Project     = var.project
    Environment = try(var.environment, "dev")
    ManagedBy   = try(var.managed_by, "terraform")
  }
}


# ------------------------------------------------------------
# Security groups
# ------------------------------------------------------------

# Jenkins SG: SSH + Jenkins UI
resource "aws_security_group" "jenkins" {
  name        = "${var.project}-jenkins-sg"
  description = "Allow SSH and Jenkins UI"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

# Mongo SG: SSH + MongoDB exposed publicly (intentional for exercise)
resource "aws_security_group" "mongo" {
  name        = "${var.project}-mongo-sg"
  description = "Allow SSH and MongoDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MongoDB"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
# Inspector2 enable (uses account ID from iam.tf)
# ------------------------------------------------------------
resource "aws_inspector2_enabler" "this" {
  account_ids = [data.aws_caller_identity.current.account_id]

  resource_types = [
    "EC2",
    "ECR",
    "LAMBDA",
  ]
}

# ------------------------------------------------------------
# VPC Flow Logs -> CloudWatch
# ------------------------------------------------------------

resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/aws/vpc/${var.project}/flows"
  retention_in_days = 30

  tags = {
    Project     = var.project
    Environment = try(var.environment, "dev")
    ManagedBy   = try(var.managed_by, "terraform")
  }
}

# IAM role for VPC flow logs to push to CW Logs
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.project}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = aws_cloudwatch_log_group.vpc_flow.arn
    }]
  })
}

resource "aws_flow_log" "vpc" {
  log_destination_type = "cloud-watch-logs"
  log_group_name       = aws_cloudwatch_log_group.vpc_flow.name
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id

  tags = {
    Project     = var.project
    Environment = try(var.environment, "dev")
    ManagedBy   = try(var.managed_by, "terraform")
  }
}


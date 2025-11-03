############################################################
# IAM for Jenkins and Mongo EC2 Instances
############################################################

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

############################################################
# Jenkins Role — ECR, EKS, and S3 access
############################################################
resource "aws_iam_role" "jenkins" {
  name               = "${var.project}-jenkins"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags = {
    Name        = "${var.project}-jenkins-role"
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
  }
}

# Inline policy combining ECR + EKS + S3 access
resource "aws_iam_role_policy" "jenkins_inline" {
  name = "${var.project}-jenkins-inline"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR push/pull
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      # EKS cluster describe/configure
      {
        Effect   = "Allow"
        Action   = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
      # S3 bucket for Mongo backups
      {
        Effect   = "Allow"
        Action   = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach AWS managed policies for good measure (optional)
resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "jenkins_eks" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Instance profile Jenkins EC2 will assume
resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project}-jenkins"
  role = aws_iam_role.jenkins.name
}

############################################################
# Mongo Role — intentionally over-permissive for Wiz exercise
############################################################
resource "aws_iam_role" "mongo_overperm" {
  name               = "${var.project}-mongo-overperm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags = {
    IntentionalWeakness = "true"
    Environment         = var.environment
    ManagedBy           = var.managed_by
    Owner               = var.owner
  }
}

resource "aws_iam_instance_profile" "mongo" {
  name = "${var.project}-mongo"
  role = aws_iam_role.mongo_overperm.name
}

resource "aws_iam_role_policy_attachment" "mongo_ec2full" {
  role       = aws_iam_role.mongo_overperm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}


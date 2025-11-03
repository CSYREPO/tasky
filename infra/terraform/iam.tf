data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Jenkins role (ECR/EKS)
resource "aws_iam_role" "jenkins" {
  name               = "${var.project}-jenkins"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project}-jenkins"
  role = aws_iam_role.jenkins.name
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "jenkins_eks" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "jenkins_eks_worker" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Over-permissive Mongo role (intentional weakness)
resource "aws_iam_role" "mongo_overperm" {
  name               = "${var.project}-mongo-overperm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = { IntentionalWeakness = "true" }
}

resource "aws_iam_instance_profile" "mongo" {
  name = "${var.project}-mongo"
  role = aws_iam_role.mongo_overperm.name
}

resource "aws_iam_role_policy_attachment" "mongo_ec2full" {
  role       = aws_iam_role.mongo_overperm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

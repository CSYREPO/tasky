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

  # Jenkins UI (now uses the variable you added in variables.tf)
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
    cidr_blocks = ["0.0.0.0/0"] # intentional weakness; later restrict to cluster/VPC
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


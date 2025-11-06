############################################################
# EC2 instances: Mongo (intentionally weak) + Jenkins
############################################################

# MongoDB EC2
resource "aws_instance" "mongo" {
  ami                         = data.aws_ami.ubuntu_2004.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.mongo.id]
  associate_public_ip_address = true

  # use existing instance profile (now defined in iam.tf as data ...)
  iam_instance_profile = data.aws_iam_instance_profile.mongo.name

  tags = {
    Name        = "${var.project}-mongo"
    Role        = "mongo"
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
  }
}

# Jenkins EC2
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.ubuntu_2004.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  associate_public_ip_address = true

  # use existing instance profile (now defined in iam.tf as data ...)
  iam_instance_profile = data.aws_iam_instance_profile.jenkins.name

  tags = {
    Name        = "${var.project}-jenkins"
    Role        = "jenkins"
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
  }
}


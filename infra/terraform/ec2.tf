############################################################
# EC2 for Mongo and Jenkins
############################################################

# use existing instance profiles (created earlier / outside this TF)
data "aws_iam_instance_profile" "mongo" {
  name = "${var.project}-mongo"
}

data "aws_iam_instance_profile" "jenkins" {
  name = "${var.project}-jenkins"
}

# pick a public subnet safely (your subnets are a map, not a list)
locals {
  first_public_subnet_id = values(aws_subnet.public)[0].id
}

resource "aws_instance" "mongo" {
  ami                         = data.aws_ami.ubuntu_2004.id
  instance_type               = "t3.micro"
  subnet_id                   = local.first_public_subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.mongo.id]
  iam_instance_profile        = data.aws_iam_instance_profile.mongo.name
  key_name                    = var.ssh_key_name

  tags = {
    Name        = "${var.project}-mongo"
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
  }
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.ubuntu_2004.id
  instance_type               = "t3.micro"
  subnet_id                   = local.first_public_subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = data.aws_iam_instance_profile.jenkins.name
  key_name                    = var.ssh_key_name

  tags = {
    Name        = "${var.project}-jenkins"
    Environment = var.environment
    ManagedBy   = var.managed_by
    Owner       = var.owner
  }
}

# outputs are elsewhere, so no need to repeat here


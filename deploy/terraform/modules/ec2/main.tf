variable "project" { type = string }
variable "instance_name" { type = string }
variable "instance_type" { type = string }
variable "subnet_id" { type = string }
variable "key_pair_name" { type = string }
variable "owner" { type = string }
variable "user_data_type" { type = string } # "jenkins" or "mongo"

variable "ami_id" {
  type    = string
  default = ""
}

variable "private_subnet_cidr" {
  type    = string
  default = ""
}

variable "mongo_backup_bucket" {
  type    = string
  default = ""
}

data "aws_subnet" "sel" {
  id = var.subnet_id
}

resource "aws_security_group" "sg" {
  name   = "${var.project}-${var.instance_name}-sg"
  vpc_id = data.aws_subnet.sel.vpc_id

  # SSH open to public (intentional weakness)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MongoDB open to private subnet only
  dynamic "ingress" {
    for_each = var.user_data_type == "mongo" && var.private_subnet_cidr != "" ? [1] : []
    content {
      from_port   = 27017
      to_port     = 27017
      protocol    = "tcp"
      cidr_blocks = [var.private_subnet_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project
    Name    = "${var.project}-${var.instance_name}-sg"
  }
}

# Default Ubuntu fallback if no AMI passed
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_instance" "ec2" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.sg.id]

  # Choose Jenkins or Mongo user_data script
  user_data = var.user_data_type == "jenkins" ? file("${path.module}/user_data/jenkins.sh.tpl") : templatefile("${path.module}/user_data/mongo.sh.tpl", { MONGO_BUCKET = var.mongo_backup_bucket })

  tags = {
    Project = var.project
    Owner   = var.owner
    Name    = "${var.project}-${var.instance_name}"
  }
}

output "public_ip" { value = aws_instance.ec2.public_ip }
output "private_ip" { value = aws_instance.ec2.private_ip }
output "public_dns" { value = aws_instance.ec2.public_dns }


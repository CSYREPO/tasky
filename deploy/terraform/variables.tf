variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_id" {
  type = string
}

variable "project" {
  type    = string
  default = "tasky-wiz"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.101.0/24"
}

variable "key_pair_name" {
  type = string
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "mongo_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "mongo_ami" {
  type = string
}

variable "eks_cluster_version" {
  type    = string
  default = "1.27"
}

variable "eks_node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "mongo_backup_bucket" {
  type = string
}

variable "owner" {
  type    = string
  default = "caseywalker"
}


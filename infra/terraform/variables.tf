variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "tasky-wiz"
}

variable "vpc_cidr" {
  type    = string
  default = "10.77.0.0/16"
}

variable "key_name" {
  type    = string
  default = "ubuntu22"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.77.0.0/24", "10.77.1.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.77.10.0/24", "10.77.11.0/24"]
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.large"
}

variable "mongo_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ecr_repo_name" {
  type    = string
  default = "tasky"
}
# tags/metadata
variable "environment" { type = string }
variable "owner" { type = string }
variable "cost_center" { type = string }
variable "managed_by" { type = string }

# eks (even if not used yet)
variable "eks_cluster_version" { type = string }
variable "eks_node_instance_type" { type = string }
variable "eks_desired_capacity" { type = number }
variable "eks_min_size" { type = number }
variable "eks_max_size" { type = number }


# Mongo backup bucket (used in EC2 user_data)
variable "mongo_backup_bucket" {
  type = string
}

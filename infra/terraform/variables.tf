#############################################
# General Configuration
#############################################

variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "tasky-wiz"
}

#############################################
# Networking
#############################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.77.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.77.0.0/24", "10.77.1.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = ["10.77.10.0/24", "10.77.11.0/24"]
}

#############################################
# EC2 Key Pair
#############################################

variable "key_name" {
  description = "Name of the EC2 key pair to use for SSH access"
  type        = string
  default     = "ubuntu22"
}

#############################################
# Instance Types
#############################################

variable "jenkins_instance_type" {
  description = "Instance type for the Jenkins server"
  type        = string
  default     = "t3.xlarge"
}

variable "mongo_instance_type" {
  description = "Instance type for the MongoDB EC2 instance"
  type        = string
  default     = "t3.medium"
}

#############################################
# ECR Configuration
#############################################

variable "ecr_repo_name" {
  description = "ECR repository name for Tasky container images"
  type        = string
  default     = "tasky"
}

#############################################
# Metadata / Tagging
#############################################

variable "environment" {
  description = "Deployment environment (e.g., dev, stage, prod)"
  type        = string
}

variable "owner" {
  description = "Owner of the infrastructure resources"
  type        = string
}

variable "cost_center" {
  description = "Cost center identifier for tracking"
  type        = string
}

variable "managed_by" {
  description = "Identifier for automation or tool managing these resources"
  type        = string
}

#############################################
# EKS Cluster Parameters
#############################################

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
}

variable "eks_desired_capacity" {
  description = "Desired node count for the EKS node group"
  type        = number
}

variable "eks_min_size" {
  description = "Minimum node count for the EKS node group"
  type        = number
}

variable "eks_max_size" {
  description = "Maximum node count for the EKS node group"
  type        = number
}

#############################################
# Mongo Backup
#############################################

variable "mongo_backup_bucket" {
  description = "S3 bucket name for MongoDB backups"
  type        = string
}

#############################################
# Jenkins Access Control
#############################################

variable "jenkins_allowed_cidrs" {
  description = "List of CIDR blocks allowed to access Jenkins UI on port 8080"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}


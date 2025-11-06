project = "tasky-wiz"
region  = "us-east-1"

vpc_cidr        = "10.77.0.0/16"
public_subnets  = ["10.77.0.0/24", "10.77.1.0/24"]
private_subnets = ["10.77.10.0/24", "10.77.11.0/24"]

jenkins_instance_type = "t3.large"
mongo_instance_type   = "t3.medium"

ecr_repo_name = "tasky"

environment = "dev"
owner       = "caseywalker"
cost_center = "devsecops"
managed_by  = "terraform"

eks_cluster_version    = "1.30"
eks_node_instance_type = "t3.large"
eks_desired_capacity   = 2
eks_min_size           = 1
eks_max_size           = 3

# 👇 add this
mongo_backup_bucket = "tasky-wiz-mongo-backups-fc0819"


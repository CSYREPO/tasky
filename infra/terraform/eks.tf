###########################################################
# EKS Cluster (public API endpoint so Jenkins can kubectl)
###########################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project}-eks"
  cluster_version = "1.29"

  vpc_id     = aws_vpc.main.id
  subnet_ids = [for s in aws_subnet.private : s.id]

  # expose API publicly so the Jenkins EC2 (public) can reach it
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  # this is the correct arg name in the module
  cluster_endpoint_public_access_cidrs = [
    "0.0.0.0/0" # 👉 for now, open so your Jenkins box can hit it
    # you can later change to your.home.ip/32
  ]

  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      instance_types = ["t3.large"]
    }
  }
}

###########################################################
# Auth + Kubernetes provider (what you already had)
###########################################################
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}


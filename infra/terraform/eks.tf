module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project}-eks"
  cluster_version = "1.29"

  vpc_id                   = aws_vpc.main.id
  subnet_ids               = [for s in aws_subnet.private : s.id]
  control_plane_subnet_ids = [for s in aws_subnet.private : s.id]

  # make API reachable by Jenkins
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = false
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # give the TF creator admin
  enable_cluster_creator_admin_permissions = true

  # let the Jenkins IAM role talk to the cluster
  access_entries = {
    jenkins = {
      principal_arn     = aws_iam_role.jenkins.arn
      kubernetes_groups = ["jenkins-admins"]
      username          = "jenkins"
    }
  }

  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      instance_types = ["t3.large"]
    }
  }
}

# -------------------------------------------------------------------
# Use data sources (not module outputs) for the Kubernetes provider
# so "terraform plan" doesn't choke
# -------------------------------------------------------------------

data "aws_eks_cluster" "this" {
  name = "${var.project}-eks"
}

data "aws_eks_cluster_auth" "this" {
  name = "${var.project}-eks"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# RBAC: make the group we gave Jenkins ("jenkins-admins") actually admin
resource "kubernetes_cluster_role_binding" "jenkins_admin" {
  metadata {
    name = "jenkins-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = "jenkins-admins" # must match access_entries group above
    api_group = "rbac.authorization.k8s.io"
  }
}


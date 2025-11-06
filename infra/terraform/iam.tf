############################################################
# IAM (use existing roles created outside TF)
# This avoids "EntityAlreadyExists" in Jenkins runs
############################################################

# Who am I?
data "aws_caller_identity" "current" {}

# Allow overriding if the names ever change
variable "jenkins_role_name" {
  type    = string
  default = "tasky-wiz-jenkins"
}

variable "mongo_overperm_role_name" {
  type    = string
  default = "tasky-wiz-mongo-overperm"
}

############################################################
# Existing Jenkins role
# - was previously `resource "aws_iam_role" "jenkins" {...}`
# - now we just read it
############################################################
data "aws_iam_role" "jenkins" {
  name = var.jenkins_role_name
}

# If the instance profile was also created already (very likely),
# read it too so EC2 code can still reference it.
data "aws_iam_instance_profile" "jenkins" {
  name = var.jenkins_role_name
}

############################################################
# Existing Mongo "over-permissive" role
############################################################
data "aws_iam_role" "mongo_overperm" {
  name = var.mongo_overperm_role_name
}

data "aws_iam_instance_profile" "mongo" {
  name = "${var.project}-mongo"
}


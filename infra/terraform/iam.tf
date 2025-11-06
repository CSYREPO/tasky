############################################################
# IAM — roles/profiles are PRE-CREATED outside this module
# We just leave this file here so the module has an IAM file,
# but we don't re-declare data sources that other files already use.
############################################################

# Intentionally empty because:
# - eks.tf already has:  data "aws_iam_role" "jenkins" { ... }
# - ec2.tf already has:  data "aws_iam_instance_profile" "jenkins" { ... }
# - ec2.tf already has:  data "aws_iam_instance_profile" "mongo" { ... }
#
# If later you need to attach extra policies to those existing roles,
# you can add *resources* here that reference those data sources, e.g.:
#
# resource "aws_iam_role_policy" "jenkins_extra" {
#   name = "${var.project}-jenkins-extra"
#   role = data.aws_iam_role.jenkins.name
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect   = "Allow"
#       Action   = ["logs:CreateLogGroup", "logs:PutRetentionPolicy"]
#       Resource = "*"
#     }]
#   })
# }
#
# ...but for now we keep it empty to avoid duplicate data errors.


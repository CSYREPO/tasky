# infra/terraform/outputs.tf

output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS API endpoint"
}

# We now READ the existing ECR repo in ecr_s3_audit.tf:
# data "aws_ecr_repository" "tasky" { name = "tasky" }
output "ecr_repo" {
  value       = data.aws_ecr_repository.tasky.repository_url
  description = "Existing ECR repo URL for tasky"
}

# We no longer create the Mongo backup bucket in TF — we pass it in via tfvars
# so just echo the variable back out
output "mongo_backup_bucket" {
  value       = var.mongo_backup_bucket
  description = "S3 bucket to hold MongoDB backups"
}

# keep these if you had them before
output "jenkins_public_ip" {
  value       = aws_instance.jenkins.public_ip
  description = "Public IP of the Jenkins EC2 instance"
}

output "mongo_public_ip" {
  value       = aws_instance.mongo.public_ip
  description = "Public IP of the Mongo EC2 instance"
}


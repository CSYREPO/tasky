output "jenkins_public_ip" {
  description = "Public IP of the Jenkins server"
  value       = aws_instance.jenkins.public_ip
}

output "mongo_public_ip" {
  description = "Public IP of the MongoDB instance"
  value       = aws_instance.mongo.public_ip
}

output "ecr_repo" {
  description = "ECR repository URL for Tasky images"
  value       = aws_ecr_repository.tasky.repository_url
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "mongo_backup_bucket" {
  description = "S3 bucket used for MongoDB backups"
  value       = aws_s3_bucket.mongo_backups.bucket
}


output "jenkins_public_ip" { value = aws_instance.jenkins.public_ip }
output "mongo_public_ip" { value = aws_instance.mongo.public_ip }
output "ecr_repo" { value = aws_ecr_repository.tasky.repository_url }
output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "mongo_backup_bucket" { value = aws_s3_bucket.mongo_backups.bucket }


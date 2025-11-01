output "jenkins_public_ip" { value = module.ec2_jenkins.public_ip }
output "jenkins_public_dns" { value = module.ec2_jenkins.public_dns }
output "mongo_public_ip" { value = module.ec2_mongo.public_ip }
output "mongo_private_ip" { value = module.ec2_mongo.private_ip }
output "ecr_repo_uri" { value = aws_ecr_repository.tasky.repository_url }
output "vpc_id" { value = module.vpc.vpc_id }
output "public_subnet_id" { value = module.vpc.public_subnet_id }
output "private_subnet_id" { value = module.vpc.private_subnet_id }


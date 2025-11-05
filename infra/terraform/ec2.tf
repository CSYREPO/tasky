###########################################################
# MongoDB EC2
###########################################################
resource "aws_instance" "mongo" {
  ami                    = data.aws_ami.ubuntu_2004.id
  instance_type          = var.mongo_instance_type
  subnet_id              = values(aws_subnet.public)[1].id
  vpc_security_group_ids = [aws_security_group.mongo.id]
  iam_instance_profile   = aws_iam_instance_profile.mongo.name
  key_name               = var.key_name

  user_data = <<EOF
#!/usr/bin/env bash
set -euxo pipefail

apt-get update -y && apt-get install -y wget gnupg awscli
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-4.4.list
apt-get update -y && apt-get install -y mongodb-org=4.4.29

# listen on all interfaces
sed -i 's/^  bindIp: .*/  bindIp: 0.0.0.0/' /etc/mongod.conf

systemctl enable --now mongod
sleep 6
mongo --eval 'db = db.getSiblingDB("admin"); if (!db.getUser("tasky")) { db.createUser({user:"tasky",pwd:"taskypass",roles:[{role:"readWrite",db:"tasky"}]}) }' || true

# enable auth
if ! grep -q '^security:' /etc/mongod.conf; then
  printf "security:\\n  authorization: enabled\\n" >> /etc/mongod.conf
else
  sed -i 's/^  authorization: .*/  authorization: enabled/' /etc/mongod.conf
fi
systemctl restart mongod
sleep 5

# backup script -> S3
install -m 0755 -d /opt/tasky
cat >/opt/tasky/backup-tasky.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
TS=$(date +%F)
mongodump --username tasky --password taskypass --authenticationDatabase admin --db tasky --archive | \
  aws s3 cp - s3://MONGO_BACKUP_BUCKET/backups/tasky-$TS.archive
EOS
chmod +x /opt/tasky/backup-tasky.sh
sed -i "s|MONGO_BACKUP_BUCKET|${var.mongo_backup_bucket}|g" /opt/tasky/backup-tasky.sh

(crontab -l 2>/dev/null; echo "15 2 * * * /opt/tasky/backup-tasky.sh") | crontab -
EOF

  tags = {
    Name        = "${var.project}-mongo"
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = var.managed_by
  }
}

###########################################################
# locals
###########################################################
locals {
  mongo_private_ip = aws_instance.mongo.private_ip
}

###########################################################
# Jenkins EC2  (no auto-user, no install-complete flags)
###########################################################

###########################################################
# Jenkins EC2 - vanilla Jenkins, show Unlock screen
###########################################################
resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.ubuntu_2004.id
  instance_type = var.jenkins_instance_type
  key_name      = var.key_name
  subnet_id     = values(aws_subnet.public)[0].id

  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
set -xe

# base deps
apt-get update -y
apt-get install -y \
  fontconfig openjdk-17-jre curl unzip apt-transport-https ca-certificates gnupg \
  awscli mongodb-clients docker.io

# docker
systemctl enable docker
systemctl restart docker

# Jenkins repo
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key -o /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

# listen on all interfaces
if grep -q "^HTTP_HOST=" /etc/default/jenkins; then
  sed -i 's/^HTTP_HOST=.*/HTTP_HOST=0.0.0.0/' /etc/default/jenkins
else
  echo "HTTP_HOST=0.0.0.0" >> /etc/default/jenkins
fi

# let jenkins user use docker (won’t hurt to do it here)
usermod -aG docker jenkins || true
systemctl restart docker

# start jenkins normally
systemctl enable jenkins
systemctl restart jenkins

# IMPORTANT:
# no /var/lib/jenkins/init.groovy.d/*
# no jenkins.install.* markers
# so Jenkins will ask for the temporary password
EOF

  tags = {
    Name        = "${var.project}-jenkins"
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = var.managed_by
  }
}


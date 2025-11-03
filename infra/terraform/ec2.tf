###########################################################
# MongoDB EC2 (your original, just formatted)
###########################################################
resource "aws_instance" "mongo" {
  ami           = data.aws_ami.ubuntu_2004.id
  instance_type = var.mongo_instance_type
  # you were already using the second public subnet
  subnet_id              = values(aws_subnet.public)[1].id
  vpc_security_group_ids = [aws_security_group.mongo.id]
  iam_instance_profile   = aws_iam_instance_profile.mongo.name
  key_name               = var.key_name

  user_data = <<-EOF
    #!/usr/bin/env bash
    set -euxo pipefail
    apt-get update -y && apt-get install -y wget gnupg awscli
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt-get update -y && apt-get install -y mongodb-org=4.4.29

    sed -i 's/^  bindIp: .*/  bindIp: 0.0.0.0/' /etc/mongod.conf

    systemctl enable --now mongod
    sleep 6
    mongo --eval 'db = db.getSiblingDB("admin"); if (!db.getUser("tasky")) { db.createUser({user:"tasky",pwd:"taskypass",roles:[{role:"readWrite",db:"tasky"}]}) }' || true

    if ! grep -q '^security:' /etc/mongod.conf; then
      printf "security:\\n  authorization: enabled\\n" >> /etc/mongod.conf
    else
      sed -i 's/^  authorization: .*/  authorization: enabled/' /etc/mongod.conf
    fi
    systemctl restart mongod
    sleep 5

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
# Jenkins EC2 (codified with mongo client + test script)
###########################################################
 
###########################################################
# Jenkins EC2 (codified with mongo client + test script)
###########################################################

locals {
  mongo_private_ip = aws_instance.mongo.private_ip
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.ubuntu_2004.id
  instance_type               = var.jenkins_instance_type
  key_name                    = var.key_name
  subnet_id                   = values(aws_subnet.public)[0].id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  associate_public_ip_address = true

  # <- this makes TF recreate the instance whenever user_data changes
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -xe

    # update & base deps
    apt-get update -y
    apt-get install -y fontconfig openjdk-17-jre curl

    # Jenkins repo
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    # install Jenkins
    apt-get update -y
    apt-get install -y jenkins

    # bind to all interfaces
    if grep -q "^HTTP_HOST=" /etc/default/jenkins; then
      sed -i 's/^HTTP_HOST=.*/HTTP_HOST=0.0.0.0/' /etc/default/jenkins
    else
      echo "HTTP_HOST=0.0.0.0" >> /etc/default/jenkins
    fi

    systemctl daemon-reload
    systemctl enable jenkins
    systemctl restart jenkins

    # install mongo client so pipelines can test DB
    apt-get install -y mongodb-clients

    # drop a test script that hits the Mongo EC2 over PRIVATE IP
    cat >/opt/test-mongo.sh <<EOS
    #!/bin/bash
    mongo --host ${local.mongo_private_ip} -u tasky -p taskypass --authenticationDatabase admin --eval 'db.adminCommand({ ping: 1 })'
    EOS
    chmod +x /opt/test-mongo.sh
  EOF

  tags = {
    Name        = "${var.project}-jenkins"
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = var.managed_by
  }
}


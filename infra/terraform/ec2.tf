# =========================
# Jenkins EC2 (Ubuntu 20.04)
# =========================
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu_2004.id
  instance_type          = var.jenkins_instance_type
  subnet_id              = values(aws_subnet.public)[0].id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name
  key_name               = var.key_name

  user_data = <<-EOF
    #!/usr/bin/env bash
    set -euxo pipefail

    # Base deps
    apt-get update -y
    apt-get install -y openjdk-17-jre curl gnupg docker.io awscli apt-transport-https ca-certificates

    # Docker for builds
    systemctl enable --now docker || true
    usermod -aG docker ubuntu || true

    # Jenkins repo + install
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list >/dev/null
    apt-get update -y
    apt-get install -y jenkins
    usermod -aG docker jenkins || true

    systemctl enable --now jenkins
  EOF

  tags = {
    Name        = "${var.project}-jenkins"
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = var.managed_by
  }
}

# ===========================================
# MongoDB EC2 (Ubuntu 20.04, MongoDB 4.4.29)
# ===========================================
resource "aws_instance" "mongo" {
  ami                    = data.aws_ami.ubuntu_2004.id
  instance_type          = var.mongo_instance_type
  subnet_id              = values(aws_subnet.public)[1].id
  vpc_security_group_ids = [aws_security_group.mongo.id]
  iam_instance_profile   = aws_iam_instance_profile.mongo.name
  key_name               = var.key_name

  # IMPORTANT: create the user *before* enabling auth
  user_data = <<-EOF
    #!/usr/bin/env bash
    set -euxo pipefail

    # Install MongoDB 4.4 + AWS CLI
    apt-get update -y && apt-get install -y wget gnupg awscli
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt-get update -y && apt-get install -y mongodb-org=4.4.29

    # Listen on all interfaces (intentional weakness)
    sed -i 's/^  bindIp: .*/  bindIp: 0.0.0.0/' /etc/mongod.conf

    # Start WITHOUT auth, then create user
    systemctl enable --now mongod
    sleep 6
    mongo --eval 'db = db.getSiblingDB("admin"); if (!db.getUser("tasky")) { db.createUser({user:"tasky",pwd:"taskypass",roles:[{role:"readWrite",db:"tasky"}]}) }' || true

    # Enable auth and restart
    if ! grep -q '^security:' /etc/mongod.conf; then
      printf "security:\\n  authorization: enabled\\n" >> /etc/mongod.conf
    else
      sed -i 's/^  authorization: .*/  authorization: enabled/' /etc/mongod.conf
    fi
    systemctl restart mongod
    sleep 5

    # Daily backup script -> S3
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

    # Cron at 02:15 UTC
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


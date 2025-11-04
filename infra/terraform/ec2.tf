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
  printf "security:\n  authorization: enabled\n" >> /etc/mongod.conf
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
# Jenkins EC2 (docker + awscli + real kubectl + init jobs)
###########################################################

locals {
  mongo_private_ip = aws_instance.mongo.private_ip
}

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
  fontconfig \
  openjdk-17-jre \
  curl \
  unzip \
  apt-transport-https \
  ca-certificates \
  gnupg \
  awscli

# docker
apt-get install -y docker.io
systemctl enable docker
systemctl restart docker
usermod -aG docker jenkins || true

# REAL kubectl
curl -L "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl
file /usr/local/bin/kubectl || true

# mongo client for the test script
apt-get install -y mongodb-clients

# Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key -o /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" >/etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

# listen on all interfaces
if grep -q "^HTTP_HOST=" /etc/default/jenkins; then
  sed -i 's/^HTTP_HOST=.*/HTTP_HOST=0.0.0.0/' /etc/default/jenkins
else
  echo "HTTP_HOST=0.0.0.0" >> /etc/default/jenkins
fi

# try to preinstall pipeline/git
/usr/bin/jenkins-plugin-cli --plugins "workflow-aggregator git" || true

# init groovy
mkdir -p /var/lib/jenkins/init.groovy.d

cat >/var/lib/jenkins/init.groovy.d/01-create-admin.groovy <<'EOG1'
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()
def realm = new HudsonPrivateSecurityRealm(false)
realm.createAccount("admin", "TaskyDemo123!")
instance.setSecurityRealm(realm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
EOG1

cat >/var/lib/jenkins/init.groovy.d/02-create-tasky-job.groovy <<'EOG2'
import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.*

def j = Jenkins.getInstance()
def jobName    = "tasky-wiz"
def gitRepo    = "https://github.com/CSYREPO/tasky.git"
def branchSpec = new BranchSpec("*/main")
def scriptPath = "Jenkinsfile"

def existing = j.getItem(jobName)
if (existing == null) {
    println("Creating pipeline job: " + jobName)
    def job = new WorkflowJob(j, jobName)

    def scm = new GitSCM(gitRepo)
    scm.branches = [branchSpec]

    def flowDef = new CpsScmFlowDefinition(scm, scriptPath)
    flowDef.setLightweight(true)

    job.setDefinition(flowDef)
    j.putItem(job)
    job.scheduleBuild2(0)
} else {
    println("Job " + jobName + " already exists, skipping.")
}

j.save()
EOG2

chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

# mongo test script (uses the private IP from Terraform)
cat >/opt/test-mongo.sh <<EOS
#!/bin/bash
mongo --host ${local.mongo_private_ip} -u tasky -p taskypass --authenticationDatabase admin --eval 'db.adminCommand({ ping: 1 })'
EOS
chmod +x /opt/test-mongo.sh

# final services restart so jenkins picks up docker group
usermod -aG docker jenkins || true
systemctl restart docker
systemctl daemon-reload
systemctl enable jenkins
systemctl restart jenkins
EOF

  tags = {
    Name        = "${var.project}-jenkins"
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = var.managed_by
  }
}


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

# backup script -> S3 (terraform var gets substituted in user_data)
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
# Jenkins EC2
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
# log user-data so we can see errors
exec > /var/log/user-data.log 2>&1
set -xe

# 1) base deps
apt-get update -y
apt-get install -y openjdk-17-jre curl gnupg ca-certificates docker.io awscli git

systemctl enable docker
systemctl restart docker

# 2) Jenkins repo + install
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key -o /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

# listen on 0.0.0.0
if grep -q "^HTTP_HOST=" /etc/default/jenkins 2>/dev/null; then
  sed -i 's/^HTTP_HOST=.*/HTTP_HOST=0.0.0.0/' /etc/default/jenkins
else
  echo "HTTP_HOST=0.0.0.0" >> /etc/default/jenkins
fi

# 3) kubectl (correct EKS URL)
curl -o /usr/local/bin/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.30.0/2024-07-31/bin/linux/amd64/kubectl
chmod +x /usr/local/bin/kubectl

# 4) let jenkins use docker
usermod -aG docker jenkins

# 5) install pipeline + git plugins
jenkins-plugin-cli --plugins "workflow-aggregator git" || true

# 6) drop Groovy init scripts
mkdir -p /var/lib/jenkins/init.groovy.d

cat >/var/lib/jenkins/init.groovy.d/01-create-admin.groovy <<'G1'
import jenkins.model.*
import hudson.security.*

def j = Jenkins.get()
def realm = new HudsonPrivateSecurityRealm(false)
realm.createAccount("admin", "TaskyDemo123!")
j.setSecurityRealm(realm)

def strat = new FullControlOnceLoggedInAuthorizationStrategy()
strat.setAllowAnonymousRead(false)
j.setAuthorizationStrategy(strat)

j.save()
G1

cat >/var/lib/jenkins/init.groovy.d/02-create-tasky-job.groovy <<'G2'
import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.*

def j = Jenkins.get()
def name = "tasky-wiz"
def repo = "https://github.com/CSYREPO/tasky.git"

if (j.getItem(name) == null) {
    def job = new WorkflowJob(j, name)
    def scm = new GitSCM(repo)
    scm.branches = [new BranchSpec("*/main")]
    def flow = new CpsScmFlowDefinition(scm, "Jenkinsfile")
    flow.setLightweight(true)
    job.setDefinition(flow)
    j.putItem(job)
    job.scheduleBuild2(0)
}
j.save()
G2

chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

# 7) restart Jenkins to load groovy
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


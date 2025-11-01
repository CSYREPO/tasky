#!/bin/bash
set -e
apt-get update -y
apt-get install -y openjdk-11-jre wget docker.io awscli gnupg
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
echo "deb https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update -y && apt-get install -y jenkins
systemctl enable --now jenkins
usermod -aG docker jenkins


#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/terraform"
terraform output -json > tfouts.json
ECR_URI=$(jq -r '.ecr_repo_uri.value' tfouts.json)
MONGO_IP=$(jq -r '.mongo_private_ip.value' tfouts.json)
cd ..
sed -i "" "s|<ECR_REPO_URI>|${ECR_URI}|g" k8s/deployment.yaml
sed -i "" "s|<MONGO_PRIVATE_IP>|${MONGO_IP}|g" k8s/deployment.yaml
echo "Patched k8s manifest with ECR=${ECR_URI} and MongoIP=${MONGO_IP}"


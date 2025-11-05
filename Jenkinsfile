pipeline {
    agent any

    environment {
        AWS_REGION    = "us-east-1"
        CLUSTER_NAME  = "tasky-wiz-eks"
        K8S_DIR       = "k8s"
        AWS_ACCOUNTID = "122610499688"
        ECR_REPO      = "tasky"
        IMAGE_TAG     = "latest"
        ECR_URL       = "${AWS_ACCOUNTID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Push Image') {
            steps {
                sh """
                  # login to ECR
                  aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}

                  # build the image from your Dockerfile at repo root
                  docker build -t ${ECR_REPO}:${IMAGE_TAG} .

                  # tag it for ECR
                  docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG}

                  # push to ECR
                  docker push ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG}
                """
            }
        }

        stage('Configure AWS & EKS') {
            steps {
                sh """
                  aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                  kubectl get nodes
                """
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh """
                  # apply the manifests you committed earlier
                  kubectl apply -f ${K8S_DIR}/

                  # show status
                  kubectl -n tasky get pods
                  kubectl -n tasky get svc
                """
            }
        }
    }
}


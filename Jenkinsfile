pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        ECR_REPO   = "122610499688.dkr.ecr.us-east-1.amazonaws.com/tasky"
        K8S_DIR    = "k8s"
        EKS_CLUSTER = "tasky-wiz-eks"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Login to ECR') {
            steps {
                sh """
                  aws ecr get-login-password --region ${AWS_REGION} \
                  | docker login --username AWS --password-stdin ${ECR_REPO}
                """
            }
        }

        stage('Build image') {
            steps {
                sh """
                  docker build -t tasky:latest .
                  docker tag tasky:latest ${ECR_REPO}:latest
                """
            }
        }

        stage('Push image') {
            steps {
                sh "docker push ${ECR_REPO}:latest"
            }
        }

        stage('Configure kubectl') {
            steps {
                sh """
                  aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
                """
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh """
                  kubectl apply -f ${K8S_DIR}/
                  kubectl -n tasky get pods
                """
            }
        }
    }
}


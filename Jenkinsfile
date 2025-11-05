pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        CLUSTER_NAME = "tasky-wiz-eks"
        K8S_DIR = "k8s"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
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
                  kubectl apply -f ${K8S_DIR}/
                  kubectl -n tasky get pods
                  kubectl -n tasky get svc
                """
            }
        }
    }
}


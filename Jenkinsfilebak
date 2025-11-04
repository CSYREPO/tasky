pipeline {
  agent any

  environment {
    AWS_REGION   = "us-east-1"
    EKS_CLUSTER  = "tasky-wiz-eks"
    ECR_REPO     = "122610499688.dkr.ecr.us-east-1.amazonaws.com/tasky"
    IMAGE_TAG    = "latest"

    // Mongo from TF
    MONGO_HOST   = "3.227.12.152"
    MONGO_USER   = "tasky"
    MONGO_PASS   = "taskypass"

    // pin it so downloads are repeatable
    KUBECTL_VERSION = "v1.30.0"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build image') {
      steps {
        sh """
          docker build -t ${ECR_REPO}:${IMAGE_TAG} .
        """
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

    stage('Push image') {
      steps {
        sh """
          docker push ${ECR_REPO}:${IMAGE_TAG}
        """
      }
    }

    stage('Wait for EKS to be ACTIVE') {
      steps {
        sh """
          echo "Waiting for EKS cluster ${EKS_CLUSTER} to be ACTIVE..."
          for i in \$(seq 1 30); do
            STATUS=\$(aws eks describe-cluster --name ${EKS_CLUSTER} --region ${AWS_REGION} --query 'cluster.status' --output text || true)
            echo "Cluster status: \$STATUS"
            if [ "\$STATUS" = "ACTIVE" ]; then
              echo "EKS cluster is ACTIVE"
              break
            fi
            sleep 10
          done
        """
      }
    }

    // NEW: make sure kubectl is real on this node
    stage('Install/Verify kubectl') {
      steps {
        sh """
          set -e

          # if kubectl exists and runs, keep it
          if command -v kubectl >/dev/null 2>&1; then
            echo "kubectl already present: \$(which kubectl)"
            kubectl version --client
          else
            echo "kubectl not found, installing..."
            curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/kubectl
            kubectl version --client
          fi
        """
      }
    }

    stage('Configure kubectl for EKS') {
      steps {
        sh """
          set -e
          aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ${AWS_REGION}
          which kubectl
          kubectl version --client
          kubectl get nodes
        """
      }
    }

    stage('Deploy Tasky to EKS') {
      steps {
        sh """
          set -e
          # assuming your k8s/ dir is in the repo
          kubectl apply -f k8s/namespace.yaml
          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml
        """
      }
    }

    stage('Verify Mongo from Jenkins') {
      steps {
        sh """
          echo "Mongo host: ${MONGO_HOST}"
          # optional: curl or mongo client check here
        """
      }
    }

  }

  post {
    failure {
      echo "Build or deploy failed — check ECR/EKS/Mongo/kubectl."
    }
  }
}


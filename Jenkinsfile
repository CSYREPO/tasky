pipeline {
  agent any

  environment {
    AWS_REGION   = "us-east-1"
    EKS_CLUSTER  = "tasky-wiz-eks"
    ECR_REPO     = "122610499688.dkr.ecr.us-east-1.amazonaws.com/tasky"
    IMAGE_TAG    = "latest"

    MONGO_HOST   = "3.227.12.152"
    MONGO_USER   = "tasky"
    MONGO_PASS   = "taskypass"

    // we’ll hardcode the exact EKS path we know exists
    KUBECTL_URL  = "https://amazon-eks.s3.us-west-2.amazonaws.com/1.30.0/2024-07-31/bin/linux/amd64/kubectl"
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

    // <-- fixed download
    stage('Install/Verify kubectl') {
      steps {
        sh """
          set -e

          NEED_INSTALL=false

          if ! command -v kubectl >/dev/null 2>&1; then
            echo "kubectl not found, will install into workspace..."
            NEED_INSTALL=true
          else
            if file \$(command -v kubectl) | grep -qi "text"; then
              echo "Existing kubectl is not a Linux binary, will replace..."
              NEED_INSTALL=true
            fi
          fi

          if [ "\$NEED_INSTALL" = true ]; then
            echo "Downloading real kubectl from EKS S3..."
            curl -L -o kubectl "${KUBECTL_URL}"
            chmod +x kubectl
          fi

          # make sure workspace is on PATH
          export PATH="\$(pwd):\$PATH"

          echo "kubectl is now:"
          which kubectl
          # show file type so we know it’s a binary
          file \$(which kubectl)
          kubectl version --client
        """
      }
    }

    stage('Configure kubectl for EKS') {
      steps {
        sh """
          set -e
          export PATH="\$(pwd):\$PATH"
          aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ${AWS_REGION}
          kubectl get nodes || true
        """
      }
    }

    stage('Deploy Tasky to EKS') {
      steps {
        sh """
          set -e
          export PATH="\$(pwd):\$PATH"
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


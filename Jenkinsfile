pipeline {
  agent any

  environment {
    AWS_REGION     = "us-east-1"
    EKS_CLUSTER    = "tasky-wiz-eks"
    ECR_REPO       = "122610499688.dkr.ecr.us-east-1.amazonaws.com/tasky"
    IMAGE_TAG      = "latest"

    MONGO_HOST     = "3.227.12.152"
    MONGO_USER     = "tasky"
    MONGO_PASS     = "taskypass"

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

    stage('Install/Verify kubectl') {
      steps {
        sh """
          set -e
          NEED_INSTALL=false

          if command -v kubectl >/dev/null 2>&1; then
            # make sure it’s a real binary, not HTML
            if file \$(command -v kubectl) | grep -qi 'text'; then
              echo "Existing kubectl is not a Linux binary, will replace..."
              NEED_INSTALL=true
            else
              echo "kubectl already present: \$(which kubectl)"
              kubectl version --client
            fi
          else
            NEED_INSTALL=true
          fi

          if [ "\$NEED_INSTALL" = "true" ]; then
            echo "Installing kubectl from EKS S3..."
            curl -L -o /tmp/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-07-31/bin/linux/amd64/kubectl
            chmod +x /tmp/kubectl
            # try to move without sudo first (if agent runs as root)
            mv /tmp/kubectl /usr/local/bin/kubectl 2>/tmp/kubectl_mv.err || {
              echo "could not move kubectl to /usr/local/bin, printing error:"
              cat /tmp/kubectl_mv.err || true
              echo "falling back to \$HOME/bin"
              mkdir -p \$HOME/bin
              mv /tmp/kubectl \$HOME/bin/kubectl
              export PATH="\$HOME/bin:\$PATH"
            }
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
          kubectl get nodes || true
        """
      }
    }

    stage('Deploy Tasky to EKS') {
      steps {
        sh """
          set -e
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
          # this is where you could curl the app or run mongo client if installed
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



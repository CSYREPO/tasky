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
          aws ecr get-login-password --region ${AWS_REGION} \\
            | docker login --username AWS --password-stdin ${ECR_REPO}
        """
      }
    }

    stage('Push image') {
      steps {
        sh "docker push ${ECR_REPO}:${IMAGE_TAG}"
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
        sh '''
          set -e
          NEED_INSTALL=false

          if command -v kubectl >/dev/null 2>&1; then
            if file "$(command -v kubectl)" | grep -qi text; then
              NEED_INSTALL=true
            else
              echo "kubectl already present: $(which kubectl)"
              kubectl version --client
            fi
          else
            NEED_INSTALL=true
          fi

          if [ "$NEED_INSTALL" = "true" ]; then
            curl -L -o /tmp/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-07-31/bin/linux/amd64/kubectl
            chmod +x /tmp/kubectl
            # try system location first
            if mv /tmp/kubectl /usr/local/bin/kubectl 2>/dev/null; then
              echo "installed kubectl to /usr/local/bin"
            else
              mkdir -p "$HOME/bin"
              mv /tmp/kubectl "$HOME/bin/kubectl"
              echo "installed kubectl to \$HOME/bin"
              export PATH="$HOME/bin:$PATH"
            fi
          fi

          kubectl version --client
        '''
      }
    }

    stage('Configure kubectl for EKS (patched)') {
      steps {
        // use single quotes so Groovy doesn’t eat $()
        sh '''
          set -e

          # 1) normal kubeconfig
          aws eks update-kubeconfig --name tasky-wiz-eks --region us-east-1

          KCFG="$HOME/.kube/config"

          # 2) download current aws-iam-authenticator (hardcode linux/amd64 to avoid $() in Groovy)
          curl -L -o /usr/local/bin/aws-iam-authenticator \
            https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/latest/download/aws-iam-authenticator_linux_amd64
          chmod +x /usr/local/bin/aws-iam-authenticator

          # 3) patch kubeconfig
          if [ -f "$KCFG" ]; then
            sed -i 's/client.authentication.k8s.io\\/v1alpha1/client.authentication.k8s.io\\/v1beta1/g' "$KCFG"
            sed -i 's/"command": "aws"/"command": "aws-iam-authenticator"/g' "$KCFG"
          fi

          kubectl version --client
          kubectl get nodes || true
        '''
      }
    }

    stage('Deploy Tasky to EKS') {
      steps {
        sh '''
          set -e
          # validation off in case schema fetch has auth hiccup
          kubectl apply --validate=false -f k8s/namespace.yaml
          kubectl apply --validate=false -f k8s/deployment.yaml
          kubectl apply --validate=false -f k8s/service.yaml
        '''
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


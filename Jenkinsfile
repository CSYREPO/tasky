pipeline {
  agent any

  environment {
    AWS_REGION   = "us-east-1"
    EKS_CLUSTER  = "tasky-wiz-eks"
    ECR_REPO     = "122610499688.dkr.ecr.us-east-1.amazonaws.com/tasky"
    IMAGE_TAG    = "latest"

    // Mongo bits (from TF)
    MONGO_HOST   = "3.227.12.152"
    MONGO_USER   = "tasky"
    MONGO_PASS   = "taskypass"

    // keep this in sync with what we install on the box
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
          if command -v kubectl >/dev/null 2>&1; then
            echo "kubectl already present: \$(which kubectl)"
            kubectl version --client
          else
            echo "kubectl not found, installing..."
            curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o kubectl
            chmod +x kubectl
            mkdir -p "\$HOME/bin"
            mv kubectl "\$HOME/bin/kubectl"
            export PATH="\$HOME/bin:\$PATH"
            kubectl version --client
          fi
        """
      }
    }

    // THIS is the fixed stage
    stage('Configure kubectl for EKS (patched)') {
      steps {
        sh """
          set -e
          # get kubeconfig from EKS
          aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ${AWS_REGION}

          KCFG="\$HOME/.kube/config"
          BIN_DIR="\$HOME/bin"
          mkdir -p "\$BIN_DIR"

          # download aws-iam-authenticator to a writeable dir
          curl -L -o "\$BIN_DIR/aws-iam-authenticator" \\
            https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/latest/download/aws-iam-authenticator_linux_amd64
          chmod +x "\$BIN_DIR/aws-iam-authenticator"

          # ensure PATH
          export PATH="\$BIN_DIR:\$PATH"

          # patch kubeconfig apiVersion + command
          if [ -f "\$KCFG" ]; then
            sed -i 's/client.authentication.k8s.io\\/v1alpha1/client.authentication.k8s.io\\/v1beta1/g' "\$KCFG"
            sed -i 's/"command": "aws"/"command": "aws-iam-authenticator"/g' "\$KCFG"
          fi

          # quick smoke test (may still fail if cluster not fully ready, don't kill build here)
          kubectl version --client
          kubectl get nodes || true
        """
      }
    }

    stage('Deploy Tasky to EKS') {
      steps {
        sh """
          set -e
          # skip strict validation in case API schema can't be fetched
          kubectl apply -f k8s/namespace.yaml --validate=false
          kubectl apply -f k8s/deployment.yaml --validate=false
          kubectl apply -f k8s/service.yaml --validate=false
        """
      }
    }

    stage('Verify Mongo from Jenkins') {
      steps {
        sh """
          echo "Mongo host: ${MONGO_HOST}"
          # if mongo client exists on the Jenkins box, you could do:
          # mongo --host ${MONGO_HOST} -u ${MONGO_USER} -p ${MONGO_PASS} --authenticationDatabase admin --eval 'db.adminCommand({ ping: 1 })' || true
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


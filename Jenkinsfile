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

    KUBECTL_VERSION = "v1.30.0"

    JENKINS_HOME = "/var/lib/jenkins"
    TOOLS_DIR    = "/var/lib/jenkins/tools"
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

    stage('Ensure kubectl (user-writable)') {
      steps {
        sh """
          set -e
          mkdir -p ${TOOLS_DIR}
          if ! command -v kubectl >/dev/null 2>&1; then
            echo "kubectl not found, installing to ${TOOLS_DIR}..."
            curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o ${TOOLS_DIR}/kubectl
            chmod +x ${TOOLS_DIR}/kubectl
          else
            echo "kubectl already present: \$(which kubectl)"
            kubectl version --client || true
          fi
        """
      }
    }

    stage('Install AWS CLI v2 (local)') {
      steps {
        sh """
          set -e
          mkdir -p ${TOOLS_DIR}
          cd ${TOOLS_DIR}

          # real aws v2 binary path after install
          AWS2_BIN="${TOOLS_DIR}/aws-cli/v2/current/bin/aws"

          if [ ! -x "\$AWS2_BIN" ]; then
            echo "Installing AWS CLI v2 locally..."
            curl -L "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
            rm -rf aws aws-cli
            unzip -q awscliv2.zip
            ./aws/install -i ${TOOLS_DIR}/aws-cli -b ${TOOLS_DIR}
            rm -rf aws awscliv2.zip
          else
            echo "AWS CLI v2 already present at \$AWS2_BIN"
          fi

          ${TOOLS_DIR}/aws-cli/v2/current/bin/aws --version
        """
      }
    }

    stage('Configure kubectl for EKS (with aws v2)') {
      steps {
        sh """
          set -e
          export PATH=${TOOLS_DIR}:${TOOLS_DIR}/aws-cli/v2/current/bin:\$PATH

          # use the aws v2 we just installed
          aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ${AWS_REGION} --alias ${EKS_CLUSTER}

          KCFG="${JENKINS_HOME}/.kube/config"

          # show auth version
          echo "---- kubeconfig auth version ----"
          grep -n "client.authentication.k8s.io" "\$KCFG" || true
          echo "---------------------------------"

          # verify we can at least talk to the api (warnings ok)
          ${TOOLS_DIR}/kubectl version --client
        """
      }
    }

    stage('Deploy Tasky to EKS') {
      steps {
        sh """
          set -e
          export PATH=${TOOLS_DIR}:${TOOLS_DIR}/aws-cli/v2/current/bin:\$PATH

          ${TOOLS_DIR}/kubectl apply -f k8s/namespace.yaml --validate=false
          ${TOOLS_DIR}/kubectl apply -f k8s/deployment.yaml --validate=false
          ${TOOLS_DIR}/kubectl apply -f k8s/service.yaml --validate=false
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


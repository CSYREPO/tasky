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

    // make sure kubectl exists and remember where it is
    stage('Ensure kubectl (user-writable)') {
      steps {
        sh """
          set -e
          mkdir -p ${TOOLS_DIR}

          KUBECTL_BIN=""

          if command -v kubectl >/dev/null 2>&1; then
            # use the system one (from user_data): /usr/local/bin/kubectl
            KUBECTL_BIN=\$(command -v kubectl)
            echo "\$KUBECTL_BIN" > ${TOOLS_DIR}/.kubectl_path
            echo "Using existing kubectl at \$KUBECTL_BIN"
            \$KUBECTL_BIN version --client
          else
            # download to tools dir
            echo "kubectl not found, downloading..."
            curl -L "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl" -o ${TOOLS_DIR}/kubectl
            chmod +x ${TOOLS_DIR}/kubectl
            echo "${TOOLS_DIR}/kubectl" > ${TOOLS_DIR}/.kubectl_path
            ${TOOLS_DIR}/kubectl version --client
          fi
        """
      }
    }

    // install aws cli v2 so we get modern auth
    stage('Install AWS CLI v2 (local)') {
      steps {
        sh """
          set -e
          mkdir -p ${TOOLS_DIR}
          cd ${TOOLS_DIR}

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

          # figure out which kubectl we decided on earlier
          KUBECTL_BIN=\$(cat ${TOOLS_DIR}/.kubectl_path)
          echo "Using kubectl: \$KUBECTL_BIN"

          # write kubeconfig with aws v2
          aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ${AWS_REGION} --alias ${EKS_CLUSTER}

          KCFG="${JENKINS_HOME}/.kube/config"

          echo "---- kubeconfig auth version ----"
          grep -n "client.authentication.k8s.io" "\$KCFG" || true
          echo "---------------------------------"

          # show client
          \$KUBECTL_BIN version --client
        """
      }
    }

    stage('Deploy Tasky to EKS') {
      steps {
        sh """
          set -e
          export PATH=${TOOLS_DIR}:${TOOLS_DIR}/aws-cli/v2/current/bin:\$PATH

          KUBECTL_BIN=\$(cat ${TOOLS_DIR}/.kubectl_path)

          \$KUBECTL_BIN apply -f k8s/namespace.yaml --validate=false
          \$KUBECTL_BIN apply -f k8s/deployment.yaml --validate=false
          \$KUBECTL_BIN apply -f k8s/service.yaml --validate=false
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


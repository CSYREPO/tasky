pipeline {
  agent any

  // tweak these if you change TF outputs
  environment {
    AWS_REGION   = "us-east-1"
    EKS_CLUSTER  = "tasky-wiz-eks"   // matches your terraform output
    ECR_REPO     = "122610499688.dkr.ecr.us-east-1.amazonaws.com/tasky"
    IMAGE_TAG    = "latest"

    // current Mongo public IP from TF outputs
    MONGO_HOST   = "3.227.12.152"
    MONGO_USER   = "tasky"
    MONGO_PASS   = "taskypass"
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

    // this is the "wait until EKS is really ready" gate
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

    stage('Configure kubectl for EKS') {
      steps {
        sh """
          aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ${AWS_REGION}
          kubectl get nodes || true
        """
      }
    }

    stage('Deploy Tasky to EKS') {
      steps {
        sh """
          # make sure namespace exists
          kubectl apply -f k8s/namespace.yaml

          # deploy workload + service
          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml

          # show what we deployed
          kubectl get pods -n tasky
          kubectl get svc -n tasky
        """
      }
    }

    stage('Verify Mongo from Jenkins') {
      steps {
        sh """
          mongo --host ${MONGO_HOST} -u ${MONGO_USER} -p ${MONGO_PASS} --authenticationDatabase admin --eval 'db.adminCommand({ ping: 1 })'
        """
      }
    }
  }

  // optional: fail the build if any stage above failed
  post {
    failure {
      echo "Build or deploy failed — check ECR/EKS/Mongo connectivity."
    }
  }
}


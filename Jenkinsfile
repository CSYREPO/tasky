pipeline {
  agent any

  environment {
    AWS_REGION   = "us-east-1"
    EKS_CLUSTER  = "tasky-wiz-eks"   // from terraform output
    ECR_REPO     = "122610499688.dkr.ecr.us-east-1.amazonaws.com/tasky"
    IMAGE_TAG    = "latest"
    // if you want to move to private IP later, change in k8s/deployment.yaml
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
          aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}
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

    stage('Configure kubectl for EKS') {
      steps {
        sh """
          aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ${AWS_REGION}
        """
      }
    }

    stage('Deploy to EKS') {
      steps {
        sh """
          kubectl apply -f k8s/namespace.yaml
          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml
        """
      }
    }

    stage('Verify Mongo from Jenkins') {
      steps {
        sh """
          mongo --host 3.227.12.152 -u tasky -p taskypass --authenticationDatabase admin --eval 'db.adminCommand({ ping: 1 })'
        """
      }
    }
  }
}


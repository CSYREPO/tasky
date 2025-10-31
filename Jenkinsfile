pipeline {
  agent any
  environment {
    AWS_REGION = 'us-east-1'
    ECR_REPO   = '122610499688.dkr.ecr.us-east-1.amazonaws.com/tasky'
    IMAGE_TAG  = 'latest'
  }
  options { timestamps() }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Docker Build') {
      steps {
        sh '''
          docker version
          docker build -t tasky:${IMAGE_TAG} .
        '''
      }
    }
    stage('ECR Login') {
      steps {
        withAWS(credentials: 'aws-tasky', region: "${AWS_REGION}") {
          sh '''
            aws ecr describe-repositories --repository-names tasky >/dev/null 2>&1 || \
              aws ecr create-repository --repository-name tasky
            aws ecr get-login-password --region ${AWS_REGION} | \
              docker login --username AWS --password-stdin ${ECR_REPO}
          '''
        }
      }
    }
    stage('Tag & Push') {
      steps {
        sh '''
          docker tag tasky:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
          docker push ${ECR_REPO}:${IMAGE_TAG}
        '''
      }
    }
    // stage('Deploy to EKS') { ... }  // add after we stand up the cluster
  }
  post {
    always {
      sh 'docker image prune -f || true'
    }
  }
}


pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPO = '<your_account_id>.dkr.ecr.us-east-1.amazonaws.com/my-static-web'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        KUBECONFIG = '/home/ubuntu/.kube/config'  // عدّل حسب مكان kubeconfig عندك على EC2
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/marven-ayoob/DevOps_Project'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh 'docker build -t $ECR_REPO:$IMAGE_TAG .'
                }
            }
        }

        stage('Login to AWS ECR') {
            steps {
                script {
                    sh '''
                    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
                    '''
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    sh 'docker push $ECR_REPO:$IMAGE_TAG'
                }
            }
        }

        stage('Update Kubernetes Deployment') {
            steps {
                script {
                    sh """
                    kubectl set image deployment/static-website-deployment static-website-container=$ECR_REPO:$IMAGE_TAG --kubeconfig=$KUBECONFIG
                    """
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    sh """
                    kubectl rollout status deployment/static-website-deployment --kubeconfig=$KUBECONFIG
                    """
                }
            }
        }
    }

    post {
        success {
            echo 'Deployment completed successfully!'
        }
        failure {
            echo 'Deployment failed. Check logs for details.'
        }
    }
}

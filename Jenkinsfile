pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        ECR_REPOSITORY = 'static-website'
        IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.substring(0,7)}"
        IMAGE_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
    }
    
    stages {
        stage('Checkout Code') {
            steps {
                echo '🔄 Checking out code from repository...'
                git branch: 'main', url: 'https://github.com/YOUR_USERNAME/YOUR_REPO.git'
                sh 'ls -la'
            }
        }
        
        stage('Create ECR Repository') {
            steps {
                echo '🏗️ Creating ECR repository if it doesn\'t exist...'
                script {
                    sh '''
                        aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_DEFAULT_REGION} || \
                        aws ecr create-repository --repository-name ${ECR_REPOSITORY} --region ${AWS_DEFAULT_REGION}
                    '''
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo '🐳 Building Docker image...'
                dir('website') {
                    script {
                        def image = docker.build("${ECR_REPOSITORY}:${IMAGE_TAG}")
                        sh "docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${IMAGE_URI}"
                        sh "docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_REPOSITORY}:latest"
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                echo '📤 Pushing image to AWS ECR...'
                script {
                    sh '''
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
                        docker push ${IMAGE_URI}
                        docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${ECR_REPOSITORY}:latest
                    '''
                }
            }
        }
        
        stage('Create EC2 with Terraform') {
            steps {
                echo '🏢 Creating EC2 infrastructure with Terraform...'
                dir('terraform') {
                    script {
                        sh '''
                            terraform init
                            terraform plan -var="image_uri=${IMAGE_URI}" -var="aws_region=${AWS_DEFAULT_REGION}"
                            terraform apply -auto-approve -var="image_uri=${IMAGE_URI}" -var="aws_region=${AWS_DEFAULT_REGION}"
                        '''
                        
                        // Get the EC2 public IP
                        env.EC2_PUBLIC_IP = sh(
                            script: "terraform output -raw ec2_public_ip",
                            returnStdout: true
                        ).trim()
                        
                        echo "✅ EC2 created with IP: ${env.EC2_PUBLIC_IP}"
                    }
                }
            }
        }
        
        stage('Configure with Ansible') {
            steps {
                echo '⚙️ Configuring server with Ansible...'
                script {
                    // Wait for EC2 to be ready
                    sh '''
                        echo "Waiting for EC2 to be ready..."
                        for i in {1..30}; do
                            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@${EC2_PUBLIC_IP} "echo 'SSH Ready'"; then
                                echo "SSH connection successful"
                                break
                            fi
                            echo "Waiting for SSH... (attempt $i/30)"
                            sleep 10
                        done
                    '''
                    
                    dir('ansible') {
                        sh '''
                            ansible-playbook -i "${EC2_PUBLIC_IP}," \
                                -u ubuntu \
                                --private-key ~/.ssh/id_rsa \
                                -e "image_uri=${IMAGE_URI}" \
                                -e "aws_region=${AWS_DEFAULT_REGION}" \
                                -e "aws_account_id=${AWS_ACCOUNT_ID}" \
                                playbook.yml
                        '''
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo '🚀 Deploying to Kubernetes cluster...'
                script {
                    // Copy K8s manifests and deploy
                    sh '''
                        scp -o StrictHostKeyChecking=no -r k8s/ ubuntu@${EC2_PUBLIC_IP}:~/
                        ssh -o StrictHostKeyChecking=no ubuntu@${EC2_PUBLIC_IP} "
                            cd ~/k8s
                            sed -i 's|IMAGE_URI_PLACEHOLDER|${IMAGE_URI}|g' deployment.yaml
                            kubectl apply -f deployment.yaml
                            kubectl apply -f service.yaml
                            kubectl get pods
                            kubectl get services
                        "
                    '''
                }
            }
        }
        
        stage('Health Check') {
            steps {
                echo '🏥 Performing health check...'
                script {
                    sh '''
                        # Get NodePort
                        NODE_PORT=$(ssh -o StrictHostKeyChecking=no ubuntu@${EC2_PUBLIC_IP} "kubectl get service static-website-service -o jsonpath='{.spec.ports[0].nodePort}'")
                        
                        echo "Application URL: http://${EC2_PUBLIC_IP}:${NODE_PORT}"
                        
                        # Health check
                        for i in {1..10}; do
                            if curl -f "http://${EC2_PUBLIC_IP}:${NODE_PORT}"; then
                                echo "✅ Health check passed!"
                                echo "🌐 Your website is live at: http://${EC2_PUBLIC_IP}:${NODE_PORT}"
                                break
                            fi
                            echo "Health check attempt $i/10..."
                            sleep 10
                        done
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo '🧹 Cleaning up Docker images...'
            sh '''
                docker rmi ${ECR_REPOSITORY}:${IMAGE_TAG} || true
                docker rmi ${IMAGE_URI} || true
                docker system prune -f || true
            '''
        }
        success {
            echo '✅ Pipeline completed successfully!'
            script {
                def nodePort = sh(
                    script: "ssh -o StrictHostKeyChecking=no ubuntu@${EC2_PUBLIC_IP} \"kubectl get service static-website-service -o jsonpath='{.spec.ports[0].nodePort}'\"",
                    returnStdout: true
                ).trim()
                
                echo """
                🎉 DEPLOYMENT SUCCESSFUL! 🎉
                
                📍 Server Details:
                   • EC2 Public IP: ${env.EC2_PUBLIC_IP}
                   • Application Port: ${nodePort}
                   
                🌐 Access Your Website:
                   http://${env.EC2_PUBLIC_IP}:${nodePort}
                   
                🐳 Docker Image:
                   ${IMAGE_URI}
                """
            }
        }
        failure {
            echo '❌ Pipeline failed. Check logs for details.'
        }
    }
}

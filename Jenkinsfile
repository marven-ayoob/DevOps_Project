pipeline {
    agent any // Jenkins master node will execute this. Docker, AWS CLI, and Terraform must be installed on it.

    environment {
        // IDs of Jenkins 'Secret text' credentials for ECR configuration
        // These MUST EXACTLY match the IDs you created in Jenkins.
        AWS_ACCOUNT_ID_CRED_ID = 'ecr-aws-account-id'
        AWS_REGION_CRED_ID = 'ecr-aws-region'
        ECR_REPOSITORY_NAME_CRED_ID = 'ecr-repository-name'

        // ID for your main AWS Credentials (Access Key & Secret Key)
        AWS_CREDENTIALS_ID_JENKINS = 'aws_credentials_id'

        // Configuration for Docker Image
        LOCAL_IMAGE_BASE_NAME = "ziad-assem/devops-project"
        
        // Resolve credentials in environment block - this is the correct way
        AWS_REGION = credentials('ecr-aws-region')
        AWS_ACCOUNT_ID = credentials('ecr-aws-account-id')
        ECR_REPOSITORY_NAME = credentials('ecr-repository-name')

        // Terraform workspace
        TF_IN_AUTOMATION = 'true'
        TF_INPUT = 'false'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
                echo 'Checkout complete.'
            }
        }

        stage('Terraform Plan & Apply') {
            steps {
                script {
                    echo "--- Stage: Terraform Infrastructure Setup ---"
                    
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID_JENKINS]]) {
                        // Initialize Terraform
                        echo "Initializing Terraform..."
                        sh '''
                            terraform init -upgrade
                        '''

                        // Create terraform.tfvars file with dynamic values
                        echo "Creating terraform.tfvars with current values..."
                        sh """
                            cat > terraform.tfvars << EOF
aws_region = "${env.AWS_REGION}"
project_name = "devops-project"
ecr_repository_name = "${env.ECR_REPOSITORY_NAME}"
EOF
                        """

                        // Plan Terraform changes
                        echo "Planning Terraform changes..."
                        sh '''
                            terraform plan -var-file=terraform.tfvars -out=tfplan
                        '''

                        // Apply Terraform changes
                        echo "Applying Terraform changes..."
                        sh '''
                            terraform apply -auto-approve tfplan
                        '''

                        // Get ECR repository URL from Terraform output
                        echo "Getting ECR repository URL from Terraform..."
                        def ecrRepoUrl = sh(
                            script: 'terraform output -raw ecr_repository_url',
                            returnStdout: true
                        ).trim()
                        
                        env.ECR_REPOSITORY_URL = ecrRepoUrl
                        echo "ECR Repository URL: ${env.ECR_REPOSITORY_URL}"

                        // Get Load Balancer DNS for later reference
                        def lbDns = sh(
                            script: 'terraform output -raw load_balancer_dns',
                            returnStdout: true
                        ).trim()
                        
                        env.LOAD_BALANCER_DNS = lbDns
                        echo "Load Balancer DNS: ${env.LOAD_BALANCER_DNS}"
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker image for ${env.LOCAL_IMAGE_BASE_NAME}..."
                script {
                    // Ensure Dockerfile is present in the workspace root
                    if (!fileExists('Dockerfile')) {
                        error "Dockerfile not found in the workspace. Cannot build image."
                    }

                    def localImageWithVersionTag = "${env.LOCAL_IMAGE_BASE_NAME}:${env.BUILD_NUMBER}"
                    def localImageWithLatestTag = "${env.LOCAL_IMAGE_BASE_NAME}:latest"

                    // The '.' indicates the build context is the current directory (workspace root)
                    sh "docker build -t ${localImageWithVersionTag} -t ${localImageWithLatestTag} ."
                    echo "Docker image built and tagged locally as: ${localImageWithVersionTag} and ${localImageWithLatestTag}"
                    
                    echo "Listing Docker images for ${env.LOCAL_IMAGE_BASE_NAME}:"
                    sh "docker images ${env.LOCAL_IMAGE_BASE_NAME}"
                }
            }
        }

        stage('Login to ECR & Push Image') {
            steps {
                script {
                    echo "--- Stage: Login to ECR & Push Image ---"
                    
                    // Validate that credentials were resolved
                    if (!env.AWS_REGION || !env.AWS_ACCOUNT_ID || !env.ECR_REPOSITORY_NAME || !env.ECR_REPOSITORY_URL) {
                        error("CRITICAL FAILURE: One or more credentials could not be resolved. Check credential IDs exist in Jenkins.")
                    }

                    def ecrRegistry = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    def ecrImageWithVersionTag = "${env.ECR_REPOSITORY_URL}:${env.BUILD_NUMBER}"
                    def ecrImageWithLatestTag = "${env.ECR_REPOSITORY_URL}:latest"
                    def localImageWithVersionTag = "${env.LOCAL_IMAGE_BASE_NAME}:${env.BUILD_NUMBER}"
                    def localImageWithLatestTag = "${env.LOCAL_IMAGE_BASE_NAME}:latest"

                    echo "INFO: ECR Registry: ${ecrRegistry}"
                    echo "INFO: Target ECR image (version tag): ${ecrImageWithVersionTag}"
                    echo "INFO: Target ECR image (latest tag): ${ecrImageWithLatestTag}"

                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID_JENKINS]]) {
                        echo "INFO: Attempting ECR login..."
                        sh "aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${ecrRegistry}"
                        echo "INFO: Docker login to ECR successful."

                        echo "INFO: Tagging images for ECR..."
                        sh "docker tag ${localImageWithVersionTag} ${ecrImageWithVersionTag}"
                        sh "docker tag ${localImageWithLatestTag} ${ecrImageWithLatestTag}"
                        echo "INFO: Images tagged for ECR."

                        echo "INFO: Pushing image with version tag (${env.BUILD_NUMBER}) to ECR..."
                        sh "docker push ${ecrImageWithVersionTag}"
                        echo "INFO: Pushing image with 'latest' tag to ECR..."
                        sh "docker push ${ecrImageWithLatestTag}"
                        echo "INFO: Docker images pushed successfully to ECR."
                    }
                }
            }
        }

        stage('Update ECS Service') {
            steps {
                script {
                    echo "--- Stage: Update ECS Service ---"
                    
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID_JENKINS]]) {
                        // Force ECS service to update with new image
                        echo "Updating ECS service to use new image..."
                        
                        def clusterName = "devops-project-cluster"
                        def serviceName = "devops-project-service"
                        
                        // Update the service to force new deployment
                        sh """
                            aws ecs update-service \
                                --cluster ${clusterName} \
                                --service ${serviceName} \
                                --force-new-deployment \
                                --region ${env.AWS_REGION}
                        """
                        
                        echo "ECS service update initiated. Waiting for deployment to complete..."
                        
                        // Wait for service to be stable
                        sh """
                            aws ecs wait services-stable \
                                --cluster ${clusterName} \
                                --services ${serviceName} \
                                --region ${env.AWS_REGION}
                        """
                        
                        echo "ECS service deployment completed successfully!"
                        
                        // Get service status
                        def serviceStatus = sh(
                            script: """
                                aws ecs describe-services \
                                    --cluster ${clusterName} \
                                    --services ${serviceName} \
                                    --region ${env.AWS_REGION} \
                                    --query 'services[0].deployments[0].status' \
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()
                        
                        echo "Service deployment status: ${serviceStatus}"
                        
                        if (serviceStatus != "PRIMARY") {
                            echo "Warning: Service deployment may not be fully stable yet."
                        }
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo "--- Stage: Verify Deployment ---"
                    
                    if (env.LOAD_BALANCER_DNS) {
                        def applicationUrl = "http://${env.LOAD_BALANCER_DNS}:8081"
                        echo "Application should be accessible at: ${applicationUrl}"
                        
                        // Wait a bit for the load balancer to be ready
                        echo "Waiting 30 seconds for load balancer to be ready..."
                        sleep(30)
                        
                        // Try to curl the application (with retries)
                        echo "Testing application availability..."
                        def maxRetries = 5
                        def retryCount = 0
                        def success = false
                        
                        while (retryCount < maxRetries && !success) {
                            try {
                                def response = sh(
                                    script: "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 30 ${applicationUrl}",
                                    returnStdout: true
                                ).trim()
                                
                                echo "HTTP Response Code: ${response}"
                                
                                if (response == "200") {
                                    success = true
                                    echo "✅ Application is responding successfully!"
                                } else {
                                    echo "❌ Application returned HTTP ${response}. Retrying..."
                                }
                            } catch (Exception e) {
                                echo "❌ Failed to connect to application: ${e.getMessage()}"
                            }
                            
                            if (!success) {
                                retryCount++
                                if (retryCount < maxRetries) {
                                    echo "Waiting 30 seconds before retry ${retryCount + 1}/${maxRetries}..."
                                    sleep(30)
                                }
                            }
                        }
                        
                        if (!success) {
                            echo "⚠️  Warning: Application may not be fully ready yet. Please check manually at: ${applicationUrl}"
                            echo "This could be due to:"
                            echo "- Application still starting up"
                            echo "- Health check configuration"
                            echo "- Network routing issues"
                        }
                        
                        echo "=== DEPLOYMENT SUMMARY ==="
                        echo "ECR Repository: ${env.ECR_REPOSITORY_URL}"
                        echo "Application URL: ${applicationUrl}"
                        echo "Build Number: ${env.BUILD_NUMBER}"
                        echo "=========================="
                    } else {
                        echo "⚠️  Load Balancer DNS not found. Check Terraform outputs."
                    }
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
            // Optional: Add cleanup of local Docker images if needed to save space on the Jenkins agent
            script {
                try {
                    def localImageWithVersionTag = "${env.LOCAL_IMAGE_BASE_NAME}:${env.BUILD_NUMBER}"
                    def localImageWithLatestTag = "${env.LOCAL_IMAGE_BASE_NAME}:latest"
                    echo "Attempting to clean up local Docker images..."
                    sh "docker rmi ${localImageWithVersionTag} || true"
                    sh "docker rmi ${localImageWithLatestTag} || true"
                    echo "Local Docker image cleanup completed."
                } catch (e) {
                    echo "Could not remove all local images during cleanup: ${e.getMessage()}"
                }
            }
        }
        success {
            echo '🎉 Pipeline succeeded!'
            echo "Your application should be accessible at: http://${env.LOAD_BALANCER_DNS}:8081"
        }
        failure {
            echo '❌ Pipeline failed!'
            echo "Check the logs above for details on what went wrong."
        }
    }
}
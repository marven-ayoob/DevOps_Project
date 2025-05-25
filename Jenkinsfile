pipeline {
    agent any // Jenkins master node will execute this. Docker and AWS CLI must be installed on it.

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
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
                echo 'Checkout complete.'
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
                    echo "DEBUG: Using credentials resolved from environment..."
                    
                    // Use the credentials that were resolved in the environment block
                    echo "DEBUG: AWS Region: ${env.AWS_REGION}"
                    echo "DEBUG: AWS Account ID: ${env.AWS_ACCOUNT_ID}"
                    echo "DEBUG: ECR Repository Name: ${env.ECR_REPOSITORY_NAME}"

                    // Validate that credentials were resolved
                    if (!env.AWS_REGION || !env.AWS_ACCOUNT_ID || !env.ECR_REPOSITORY_NAME) {
                        error("CRITICAL FAILURE: One or more credentials could not be resolved. Check credential IDs exist in Jenkins.")
                    }

                    def ecrRegistry = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    def ecrImageWithVersionTag = "${ecrRegistry}/${env.ECR_REPOSITORY_NAME}:${env.BUILD_NUMBER}"
                    def ecrImageWithLatestTag = "${ecrRegistry}/${env.ECR_REPOSITORY_NAME}:latest"
                    def localImageWithVersionTag = "${env.LOCAL_IMAGE_BASE_NAME}:${env.BUILD_NUMBER}"
                    def localImageWithLatestTag = "${env.LOCAL_IMAGE_BASE_NAME}:latest"

                    echo "INFO: Constructed ECR Registry: ${ecrRegistry}"
                    echo "INFO: Target ECR image (version tag): ${ecrImageWithVersionTag}"
                    echo "INFO: Target ECR image (latest tag): ${ecrImageWithLatestTag}"

                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID_JENKINS]]) {
                        // This binding makes AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, 
                        // and AWS_SESSION_TOKEN (if applicable) available as environment variables.

                        echo "INFO: Successfully bound AWS main credentials. Attempting ECR login..."
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

        // Optional: Add a Test stage if you have automated tests for your container/application
        // stage('Test Application') {
        //     steps {
        //         echo 'Test stage: Placeholder for container tests or other application tests.'
        //         // Example: sh 'docker run --rm your-image-name:${env.BUILD_NUMBER} your-test-command'
        //     }
        // }
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
            echo 'Pipeline succeeded!'
            // You could add notifications here (e.g., Slack, email)
        }
        failure {
            echo 'Pipeline failed!'
            // You could add notifications here
        }
    }
}

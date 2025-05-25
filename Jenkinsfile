pipeline {
    agent any // Jenkins master node will execute this. Docker and AWS CLI must be installed on it.

    environment {
        // --- IDs of Jenkins 'Secret text' credentials for ECR configuration ---
        // Updated based on your screenshot:
        AWS_ACCOUNT_ID_CRED_ID = 'ecr-aws-account-id'      // <<== VERIFY THIS ID in Jenkins (especially if it has a space)
        AWS_REGION_CRED_ID = 'ecr-aws-region'
        ECR_REPOSITORY_NAME_CRED_ID = 'ecr-repository-name'

        // --- ID for your main AWS Credentials (Access Key & Secret Key) ---
        // Updated based on your screenshot:
        AWS_CREDENTIALS_ID_JENKINS = 'aws_credentials_id'

        // --- Configuration for Docker Image (from your existing build stage) ---
        LOCAL_IMAGE_BASE_NAME = "marven-ayoob/devops-static-website" // Base name for the image built locally
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
                echo 'Checkout complete.'
            }
        }

        stage('Show File Content') { // As per your provided Jenkinsfile
            steps {
                echo 'Reading test-pipeline.txt...'
                script {
                    if (fileExists('test-pipeline.txt')) {
                        def fileContent = readFile 'test-pipeline.txt'
                        echo "Contents of test-pipeline.txt:"
                        echo "------------------------------------"
                        echo fileContent.trim() // .trim() is good practice
                        echo "------------------------------------"
                    } else {
                        echo "WARNING: test-pipeline.txt not found in the workspace."
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker image for ${env.LOCAL_IMAGE_BASE_NAME}..."
                script {
                    def localImageWithVersionTag = "${env.LOCAL_IMAGE_BASE_NAME}:${env.BUILD_NUMBER}"
                    def localImageWithLatestTag = "${env.LOCAL_IMAGE_BASE_NAME}:latest"

                    if (fileExists('Dockerfile')) {
                        sh "docker build -t ${localImageWithVersionTag} -t ${localImageWithLatestTag} ."
                        echo "Docker image built and tagged locally as: ${localImageWithVersionTag} and ${localImageWithLatestTag}"
                        sh "docker images ${env.LOCAL_IMAGE_BASE_NAME}"
                    } else {
                        error "Dockerfile not found in the workspace. Cannot build image."
                    }
                }
            }
        }

        stage('Login to ECR & Push Image') {
            steps {
                script {
                    // Retrieve ECR configuration from Jenkins 'Secret text' credentials
                    def awsRegion = credentials(env.AWS_REGION_CRED_ID)
                    def awsAccountId = credentials(env.AWS_ACCOUNT_ID_CRED_ID)
                    def ecrRepositoryName = credentials(env.ECR_REPOSITORY_NAME_CRED_ID)

                    // Basic validation that credentials were fetched
                    if (!awsRegion || !awsAccountId || !ecrRepositoryName) {
                        error("Failed to retrieve one or more ECR configuration credentials (Region, Account ID, or Repo Name). " +
                              "Please check that the Jenkinsfile environment variables (e.g., AWS_REGION_CRED_ID) " +
                              "correctly point to existing 'Secret text' credential IDs in Jenkins that match EXACTLY.")
                    }

                    // Construct the full ECR registry path and image names
                    def ecrRegistry = "${awsAccountId}.dkr.ecr.${awsRegion}.amazonaws.com"
                    def ecrImageWithVersionTag = "${ecrRegistry}/${ecrRepositoryName}:${env.BUILD_NUMBER}"
                    def ecrImageWithLatestTag = "${ecrRegistry}/${ecrRepositoryName}:latest"
                    
                    def localImageWithVersionTag = "${env.LOCAL_IMAGE_BASE_NAME}:${env.BUILD_NUMBER}"
                    def localImageWithLatestTag = "${env.LOCAL_IMAGE_BASE_NAME}:latest"

                    echo "Resolved AWS Region: ${awsRegion}"
                    echo "Resolved AWS Account ID: ${awsAccountId}"
                    echo "Resolved ECR Repository Name: ${ecrRepositoryName}"
                    echo "Constructed ECR Registry: ${ecrRegistry}"
                    echo "Target ECR image (version tag): ${ecrImageWithVersionTag}"
                    echo "Target ECR image (latest tag): ${ecrImageWithLatestTag}"

                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID_JENKINS]]) {
                        // This binding makes AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, 
                        // and AWS_SESSION_TOKEN (if applicable) available as environment variables.

                        echo "Logging into Amazon ECR (Registry: ${ecrRegistry})..."
                        sh "aws ecr get-login-password --region ${awsRegion} | docker login --username AWS --password-stdin ${ecrRegistry}"
                        echo "Docker login to ECR successful."

                        echo "Tagging images for ECR..."
                        sh "docker tag ${localImageWithVersionTag} ${ecrImageWithVersionTag}"
                        sh "docker tag ${localImageWithLatestTag} ${ecrImageWithLatestTag}"
                        echo "Images tagged for ECR."

                        echo "Pushing image with version tag (${env.BUILD_NUMBER}) to ECR..."
                        sh "docker push ${ecrImageWithVersionTag}"
                        echo "Pushing image with 'latest' tag to ECR..."
                        sh "docker push ${ecrImageWithLatestTag}"
                        echo "Docker images pushed successfully to ECR: ${ecrImageWithVersionTag} and ${ecrImageWithLatestTag}"
                    }
                }
            }
        }

        stage('Test') { // Placeholder
            steps {
                echo 'Test stage: Placeholder for container tests or other tests'
            }
        }

        stage('Deploy') { // Placeholder
            steps {
                echo "Deploy stage: Image pushed to ECR. Next steps could involve updating a service."
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
            // Optional cleanup
            // script {
            //     try {
            //         def localImageWithVersionTag = "${env.LOCAL_IMAGE_BASE_NAME}:${env.BUILD_NUMBER}"
            //         def localImageWithLatestTag = "${env.LOCAL_IMAGE_BASE_NAME}:latest"
            //         echo "Cleaning up local Docker images: ${localImageWithVersionTag} and ${localImageWithLatestTag}"
            //         sh "docker rmi ${localImageWithVersionTag} || true"
            //         sh "docker rmi ${localImageWithLatestTag} || true"
            //     } catch (e) {
            //         echo "Could not remove all local images: ${e.getMessage()}"
            //     }
            // }
        }
    }
}

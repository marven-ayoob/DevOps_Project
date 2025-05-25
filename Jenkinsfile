pipeline {
    agent any // Jenkins master node will execute this. Docker and AWS CLI must be installed on it.

    environment {
        // --- IDs of Jenkins 'Secret text' credentials for ECR configuration ---
        // Replace these IDs with the actual IDs you created in Jenkins:
        AWS_ACCOUNT_ID_CRED_ID = 'ecr-aws-account-id'      // <<== UPDATE THIS
        AWS_REGION_CRED_ID = 'ecr-aws-region'               // <<== UPDATE THIS
        ECR_REPOSITORY_NAME_CRED_ID = 'ecr-repository-name' // <<== UPDATE THIS

        // --- ID for your main AWS Credentials (Access Key & Secret Key) ---
        // This should be the ID of the 'AWS Credentials' kind you already added.
        AWS_CREDENTIALS_ID_JENKINS = 'aws-ecr-credentials' // <<== VERIFY/UPDATE THIS

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
                        echo fileContent.trim()
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
                        // Your manual step: docker build -t devops-project .
                        // This Jenkinsfile builds with LOCAL_IMAGE_BASE_NAME and adds BUILD_NUMBER and latest tags.
                        // This is more robust for tracking.
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

                    // Construct the full ECR registry path and image names
                    def ecrRegistry = "${awsAccountId}.dkr.ecr.${awsRegion}.amazonaws.com"
                    def ecrImageWithVersionTag = "${ecrRegistry}/${ecrRepositoryName}:${env.BUILD_NUMBER}"
                    def ecrImageWithLatestTag = "${ecrRegistry}/${ecrRepositoryName}:latest"
                    
                    def localImageWithVersionTag = "${env.LOCAL_IMAGE_BASE_NAME}:${env.BUILD_NUMBER}"
                    // Note: Your manual example tags 'devops-project:latest'.
                    // This script tags the locally built image (e.g., 'marven-ayoob/devops-static-website:latest')
                    // to the ECR equivalent.
                    def localImageWithLatestTag = "${env.LOCAL_IMAGE_BASE_NAME}:latest"


                    echo "ECR Registry: ${ecrRegistry}"
                    echo "ECR Repository: ${ecrRepositoryName}"
                    echo "Target ECR image (version tag): ${ecrImageWithVersionTag}"
                    echo "Target ECR image (latest tag): ${ecrImageWithLatestTag}"

                    // Use withCredentials to securely handle actual AWS Access/Secret Keys
                    // The 'region' parameter here will use the 'awsRegion' fetched from credentials.
                    withCredentials([aws(credentials: env.AWS_CREDENTIALS_ID_JENKINS, region: awsRegion)]) {
                        // AWS CLI is configured by the aws(...) binding.

                        echo "Logging into Amazon ECR (Registry: ${ecrRegistry})..."
                        // Your manual step: aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com
                        sh "aws ecr get-login-password --region ${awsRegion} | docker login --username AWS --password-stdin ${ecrRegistry}"
                        echo "Docker login to ECR successful."

                        echo "Tagging images for ECR..."
                        // Your manual step: docker tag devops-project:latest ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/devops-project:latest
                        // This script tags both the BUILD_NUMBER and latest versions of your locally built image.
                        sh "docker tag ${localImageWithVersionTag} ${ecrImageWithVersionTag}"
                        sh "docker tag ${localImageWithLatestTag} ${ecrImageWithLatestTag}"
                        echo "Images tagged for ECR."

                        echo "Pushing image with version tag (${env.BUILD_NUMBER}) to ECR..."
                        // Your manual step: docker push ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/devops-project:latest
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

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
        LOCAL_IMAGE_BASE_NAME = "ziad-assem/devops-project" // <<=== UPDATED
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
                    echo "DEBUG: Attempting to retrieve credential IDs from environment..."
                    String retrievedAwsRegionCredId = env.AWS_REGION_CRED_ID
                    String retrievedAwsAccountIdCredId = env.AWS_ACCOUNT_ID_CRED_ID
                    String retrievedEcrRepoNameCredId = env.ECR_REPOSITORY_NAME_CRED_ID
                    String retrievedAwsCredsJenkinsId = env.AWS_CREDENTIALS_ID_JENKINS

                    echo "DEBUG: AWS_REGION_CRED_ID = '${retrievedAwsRegionCredId}'"
                    echo "DEBUG: AWS_ACCOUNT_ID_CRED_ID = '${retrievedAwsAccountIdCredId}'"
                    echo "DEBUG: ECR_REPOSITORY_NAME_CRED_ID = '${retrievedEcrRepoNameCredId}'"
                    echo "DEBUG: AWS_CREDENTIALS_ID_JENKINS = '${retrievedAwsCredsJenkinsId}'"

                    if (retrievedAwsRegionCredId == null || retrievedAwsAccountIdCredId == null || retrievedEcrRepoNameCredId == null || retrievedAwsCredsJenkinsId == null) {
                        error("CRITICAL FAILURE: One or more credential ID variables in the Jenkinsfile 'environment' block is null. Check for typos or ensure they are defined.")
                    }
                    if (retrievedAwsRegionCredId.isEmpty() || retrievedAwsAccountIdCredId.isEmpty() || retrievedEcrRepoNameCredId.isEmpty() || retrievedAwsCredsJenkinsId.isEmpty()) {
                        error("CRITICAL FAILURE: One or more credential ID variables in the Jenkinsfile 'environment' block is empty. Check definitions.")
                    }
                    
                    echo "DEBUG: Attempting to resolve secret text credentials..."
                    def awsRegion = credentials(retrievedAwsRegionCredId)
                    def awsAccountId = credentials(retrievedAwsAccountIdCredId)
                    def ecrRepositoryName = credentials(retrievedEcrRepoNameCredId)

                    echo "DEBUG: Value returned by credentials('${retrievedAwsRegionCredId}'): '${awsRegion}' (Class: ${(awsRegion != null) ? awsRegion.getClass().getName() : 'null'})"
                    echo "DEBUG: Value returned by credentials('${retrievedAwsAccountIdCredId}'): '${awsAccountId}' (Class: ${(awsAccountId != null) ? awsAccountId.getClass().getName() : 'null'})"
                    echo "DEBUG: Value returned by credentials('${retrievedEcrRepoNameCredId}'): '${ecrRepositoryName}' (Class: ${(ecrRepositoryName != null) ? ecrRepositoryName.getClass().getName() : 'null'})"

                    // Explicit check if the credentials() step returned the placeholder string or null
                    if (awsRegion == null || (awsRegion instanceof String && awsRegion.startsWith('@credentials('))) {
                        error("CRITICAL FAILURE: credentials('${retrievedAwsRegionCredId}') did NOT resolve to a secret. It returned: '${awsRegion}'. This indicates a problem with the Credentials Binding plugin or its usage, or the credential ID is incorrect/missing.")
                    }
                    if (awsAccountId == null || (awsAccountId instanceof String && awsAccountId.startsWith('@credentials('))) {
                        error("CRITICAL FAILURE: credentials('${retrievedAwsAccountIdCredId}') did NOT resolve to a secret. It returned: '${awsAccountId}'.")
                    }
                    if (ecrRepositoryName == null || (ecrRepositoryName instanceof String && ecrRepositoryName.startsWith('@credentials('))) {
                        error("CRITICAL FAILURE: credentials('${retrievedEcrRepoNameCredId}') did NOT resolve to a secret. It returned: '${ecrRepositoryName}'.")
                    }
                    
                    echo "INFO: Resolved AWS Region: ${awsRegion}"
                    echo "INFO: Resolved AWS Account ID: ${awsAccountId}"
                    echo "INFO: Resolved ECR Repository Name: ${ecrRepositoryName}"

                    def ecrRegistry = "${awsAccountId}.dkr.ecr.${awsRegion}.amazonaws.com"
                    def ecrImageWithVersionTag = "${ecrRegistry}/${ecrRepositoryName}:${env.BUILD_NUMBER}"
                    def ecrImageWithLatestTag = "${ecrRegistry}/${ecrRepositoryName}:latest"
                    def localImageWithVersionTag = "${env.LOCAL_IMAGE_BASE_NAME}:${env.BUILD_NUMBER}"
                    def localImageWithLatestTag = "${env.LOCAL_IMAGE_BASE_NAME}:latest"

                    echo "INFO: Constructed ECR Registry: ${ecrRegistry}"
                    echo "INFO: Target ECR image (version tag): ${ecrImageWithVersionTag}"
                    echo "INFO: Target ECR image (latest tag): ${ecrImageWithLatestTag}"

                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: retrievedAwsCredsJenkinsId]]) {
                        // This binding makes AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, 
                        // and AWS_SESSION_TOKEN (if applicable) available as environment variables.
                        // AWS_DEFAULT_REGION is NOT set by this binding directly, so --region is important for CLI.

                        echo "INFO: Successfully bound AWS main credentials (ID: '${retrievedAwsCredsJenkinsId}'). Attempting ECR login..."
                        sh "aws ecr get-login-password --region ${awsRegion} | docker login --username AWS --password-stdin ${ecrRegistry}"
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
            // This is useful if your Jenkins agent has limited disk space.
            // script {
            //     def localImageWithVersionTag = "${env.LOCAL_IMAGE_BASE_NAME}:${env.BUILD_NUMBER}"
            //     def localImageWithLatestTag = "${env.LOCAL_IMAGE_BASE_NAME}:latest"
            //     def ecrRegistry = credentials(env.AWS_ACCOUNT_ID_CRED_ID) + ".dkr.ecr." + credentials(env.AWS_REGION_CRED_ID) + ".amazonaws.com"
            //     def ecrImageWithVersionTag = ecrRegistry + "/" + credentials(env.ECR_REPOSITORY_NAME_CRED_ID) + ":${env.BUILD_NUMBER}"
            //     def ecrImageWithLatestTag = ecrRegistry + "/" + credentials(env.ECR_REPOSITORY_NAME_CRED_ID) + ":latest"
            //     try {
            //         echo "Attempting to clean up local Docker images..."
            //         sh "docker rmi ${localImageWithVersionTag} || true"
            //         sh "docker rmi ${localImageWithLatestTag} || true"
            //         // Be cautious removing images tagged for ECR if you might re-tag locally later,
            //         // but generally, after a successful push, they might not be needed locally on the agent.
            //         // sh "docker rmi ${ecrImageWithVersionTag} || true" 
            //         // sh "docker rmi ${ecrImageWithLatestTag} || true"
            //         echo "Local Docker image cleanup attempted."
            //     } catch (e) {
            //         echo "Could not remove all local images during cleanup: ${e.getMessage()}"
            //     }
            // }
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

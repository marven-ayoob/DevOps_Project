pipeline {
    agent any // Jenkins master node will execute this. Docker must be installed on it.

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
                echo 'Checkout complete.'
            }
        }

        stage('Show File Content') {
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

        stage('Build Docker Image') { // Renamed for clarity, was 'Build'
            steps {
                echo 'Building Docker image for the static website...'
                script {
                    // Define your image name and tag
                    // Using Jenkins's BUILD_NUMBER is a good practice for versioning
                    def imageName = "marven-ayoob/devops-static-website:${env.BUILD_NUMBER}"
                    def latestTag = "marven-ayoob/devops-static-website:latest"

                    // Ensure Dockerfile is present
                    if (fileExists('Dockerfile')) {
                        // Run the docker build command
                        // The '.' indicates the build context is the current directory (workspace root)
                        sh "docker build -t ${imageName} -t ${latestTag} ."
                        echo "Docker image built successfully: ${imageName} and ${latestTag}"

                        // Optional: List Docker images to verify
                        sh "docker images ${imageName}"
                    } else {
                        error "Dockerfile not found in the workspace. Cannot build image."
                    }
                }
            }
        }

        stage('Test') { // Placeholder - you might add tests for your container later
            steps {
                echo 'Test stage: Placeholder for container tests or other tests'
            }
        }

        stage('Deploy') { // Placeholder for deploying the built image
            steps {
                echo 'Deploy stage: Placeholder for deployment commands'
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
            // You might add cleanup steps here if needed
        }
    }
}
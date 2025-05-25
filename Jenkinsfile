pipeline {
    agent any // Runs on any available agent (your master node)

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm // This ensures your code, including test-pipeline.txt, is available
                echo 'Checkout complete.'
            }
        }

        stage('Show File Content') { // New stage to display the file
            steps {
                echo 'Reading test-pipeline.txt...'
                script {
                    // Check if the file exists before trying to read it
                    if (fileExists('test-pipeline.txt')) {
                        def fileContent = readFile 'test-pipeline.txt'
                        echo "Contents of test-pipeline.txt:"
                        echo "------------------------------------"
                        echo fileContent.trim() // .trim() removes leading/trailing whitespace
                        echo "------------------------------------"
                    } else {
                        echo "WARNING: test-pipeline.txt not found in the workspace."
                    }
                }
            }
        }

        stage('Build') {
            steps {
                echo 'Build stage: Placeholder for build commands'
                // You can add your actual build commands here later
            }
        }

        stage('Test') {
            steps {
                echo 'Test stage: Placeholder for test commands'
                // You can add your actual test commands here later
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploy stage: Placeholder for deployment commands'
                // You can add your actual deployment commands here later
            }
        }
    }
}
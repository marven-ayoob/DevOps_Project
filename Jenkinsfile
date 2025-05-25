pipeline {
    agent any // Runs on any available agent (your master node)

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm // This is the key command for checking out the code
                echo 'Checkout complete.'
            }
        }
        stage('Build') {
            steps {
                echo 'Build stage: Placeholder for build commands'
            }
        }
        stage('Test') {
            steps {
                echo 'Test stage: Placeholder for test commands'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploy stage: Placeholder for deployment commands'
            }
        }
    }
}

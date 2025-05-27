pipeline {
    agent any

    environment {
        AWS_REGION = credentials('ecr-aws-region')
        AWS_ACCOUNT_ID = credentials('ecr-aws-account-id')
        ECR_REPO_NAME = credentials('ecr-repository-name')
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo 'Checking out code...'
                checkout scm
            }
        }

        stage('Terraform Init, Plan & Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws_credentials_id']]) {
                    dir('terraform') {
                        sh '''
                            terraform init -upgrade

                            cat > terraform.tfvars <<EOF
                            ecr_repo_name = "${ECR_REPO_NAME}"
                            EOF

                            terraform plan -var-file=terraform.tfvars -out=tfplan
                            terraform apply -auto-approve tfplan
                        '''
                    }
                }
            }
        }

        stage('Fetch Terraform Outputs') {
            steps {
                script {
                    dir('terraform') {
                        env.ECR_REPO_URL = sh(script: "terraform output -raw ecr_repository_url", returnStdout: true).trim()
                        env.ECS_CLUSTER = sh(script: "terraform output -raw ecs_cluster_name", returnStdout: true).trim()
                        env.ECS_SERVICE = sh(script: "terraform output -raw ecs_service_name", returnStdout: true).trim()
                        env.TASK_EXEC_ROLE = sh(script: "terraform output -raw task_execution_role_arn", returnStdout: true).trim()
                        echo "ECR URL: ${env.ECR_REPO_URL}"
                        echo "ECS Cluster: ${env.ECS_CLUSTER}"
                        echo "ECS Service: ${env.ECS_SERVICE}"
                    }
                }
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                sh '''
                    docker build -t ${ECR_REPO_URL}:9 .
                    docker tag ${ECR_REPO_URL}:9 ${ECR_REPO_URL}:latest

                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                    docker push ${ECR_REPO_URL}:9
                    docker push ${ECR_REPO_URL}:latest
                '''
            }
        }

        stage('Register New Task Definition') {
            steps {
                script {
                    def taskDefJson = """
                    {
                      "family": "${env.ECS_SERVICE}",
                      "executionRoleArn": "${env.TASK_EXEC_ROLE}",
                      "networkMode": "awsvpc",
                      "containerDefinitions": [
                        {
                          "name": "app",
                          "image": "${env.ECR_REPO_URL}:latest",
                          "essential": true,
                          "portMappings": [
                            {
                              "containerPort": 80,
                              "hostPort": 80,
                              "protocol": "tcp"
                            }
                          ]
                        }
                      ],
                      "requiresCompatibilities": ["FARGATE"],
                      "cpu": "256",
                      "memory": "512"
                    }
                    """.stripIndent()

                    writeFile file: 'task-def.json', text: taskDefJson

                    sh '''
                        aws ecs register-task-definition \
                          --cli-input-json file://task-def.json \
                          --region ${AWS_REGION}
                    '''
                }
            }
        }

        stage('Update ECS Service') {
            steps {
                script {
                    def newTaskDefArn = sh(
                        script: """
                          aws ecs describe-task-definition \
                          --task-definition ${env.ECS_SERVICE} \
                          --query 'taskDefinition.taskDefinitionArn' \
                          --output text \
                          --region ${AWS_REGION}
                        """, returnStdout: true
                    ).trim()

                    sh """
                        aws ecs update-service \
                          --cluster ${env.ECS_CLUSTER} \
                          --service ${env.ECS_SERVICE} \
                          --task-definition ${newTaskDefArn} \
                          --region ${AWS_REGION}
                    """
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                echo '✅ ECS service updated with new task definition.'
            }
        }
    }

    post {
        always {
            echo 'Cleaning up...'
            sh '''
                docker rmi ${ECR_REPO_URL}:9 || true
                docker rmi ${ECR_REPO_URL}:latest || true
            '''
        }
        failure {
            echo '❌ Pipeline failed.'
        }
    }
}

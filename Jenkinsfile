pipeline {
    agent any

    environment {
        REPO_URL = 'https://github.com/betechsol/BETECH-APP-DEPLOYMENT.git'
        BRANCH = 'main'
        FRONTEND_DIR = 'betech-login-frontend'
        BACKEND_DIR = 'betech-login-backend'
        DB_DIR = 'betech-postgresql-db'
        DOCKER_IMAGE_FRONTEND = 'betechinc/betech-app-deployment_betechnet-frontend:v1.1'
        DOCKER_IMAGE_BACKEND = 'betechinc/betech-app-deployment_betechnet-backend:v1.0'
        DOCKER_IMAGE_DB = 'postgres:14'
        SONARQUBE_SERVER = 'SonarQubeServer'
        DOCKERHUB_CREDENTIALS = 'dockerhub-creds'
        NEXUS_URL = 'http://34.209.95.93:8081/repository/betech-login-backend-snapshot/'
        NEXUS_CREDENTIALS = 'nexus-creds'
        SLACK_CHANNEL = '#your-slack-channel'
        SLACK_CREDENTIALS = 'slack-token-id'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: "${BRANCH}", url: "${REPO_URL}"
            }
        }

        stage('Frontend Test & Build') {
            steps {
                dir("${FRONTEND_DIR}") {
                    sh 'npm install'
                    sh 'npm run test'
                    sh 'npm run build'
                }
            }
        }

        stage('Backend Test & Build') {
            steps {
                dir("${BACKEND_DIR}") {
                    sh 'mvn clean test'
                    sh 'mvn clean package -DskipTests'
                }
            }
        }

        stage('DB Build') {
            steps {
                dir("${DB_DIR}") {
                    // Add DB build steps if needed, e.g., for migrations or schema validation
                    echo 'DB build step (customize as needed)'
                }
            }
        }

        stage('SonarQube Scan') {
            steps {
                dir("${BACKEND_DIR}") {
                    withSonarQubeEnv("${SONARQUBE_SERVER}") {
                        sh """
                            mvn sonar:sonar \
                              -Dsonar.projectKey=betech-login-backend \
                              -Dsonar.projectName=betech-login-backend \
                              -Dsonar.projectVersion=1.0
                        """
                    }
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    sh "docker build -t ${DOCKER_IMAGE_FRONTEND}:${BUILD_NUMBER} ${FRONTEND_DIR}"
                    sh "docker build -t ${DOCKER_IMAGE_BACKEND}:${BUILD_NUMBER} ${BACKEND_DIR}"
                    sh "docker build -t ${DOCKER_IMAGE_DB}:${BUILD_NUMBER} ${DB_DIR}"
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${DOCKER_IMAGE_FRONTEND}:${BUILD_NUMBER}"
                sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${DOCKER_IMAGE_BACKEND}:${BUILD_NUMBER}"
                sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${DOCKER_IMAGE_DB}:${BUILD_NUMBER}"
            }
        }

        stage('Push Docker Images') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh "echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin"
                    sh "docker push ${DOCKER_IMAGE_FRONTEND}:${BUILD_NUMBER}"
                    sh "docker push ${DOCKER_IMAGE_BACKEND}:${BUILD_NUMBER}"
                    sh "docker push ${DOCKER_IMAGE_DB}:${BUILD_NUMBER}"
                }
            }
        }

        stage('Publish Backend Artifact to Nexus') {
            steps {
                dir("${BACKEND_DIR}") {
                    withCredentials([usernamePassword(credentialsId: "${NEXUS_CREDENTIALS}", usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                        sh """
                            mvn deploy -DskipTests \
                              -Dnexus.url=${NEXUS_URL} \
                              -Dnexus.username=$NEXUS_USER \
                              -Dnexus.password=$NEXUS_PASS
                        """
                    }
                }
            }
        }

        stage('Build docker-compose.yml') {
            steps {
                writeFile file: 'docker-compose.yml', text: """
version: "3.8"
services:
  frontend:
    image: ${DOCKER_IMAGE_FRONTEND}:${BUILD_NUMBER}
    ports:
      - "3000:3000"
  backend:
    image: ${DOCKER_IMAGE_BACKEND}:${BUILD_NUMBER}
    ports:
      - "8080:8080"
  db:
    image: ${DOCKER_IMAGE_DB}:${BUILD_NUMBER}
    ports:
      - "5432:5432"
"""
            }
        }
    }

    post {
        success {
            slackSend (
                channel: "${SLACK_CHANNEL}",
                color: '#36a64f',
                message: "Build #${BUILD_NUMBER} for ${env.JOB_NAME} succeeded! :tada:",
                tokenCredentialId: "${SLACK_CREDENTIALS}"
            )
        }
        failure {
            slackSend (
                channel: "${SLACK_CHANNEL}",
                color: '#FF0000',
                message: "Build #${BUILD_NUMBER} for ${env.JOB_NAME} failed! :x:",
                tokenCredentialId: "${SLACK_CREDENTIALS}"
            )
        }
    }
}
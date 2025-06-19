pipeline {
    agent any

    environment {
        REPO_URL = 'https://github.com/betechsol/BETECH-APP-DEPLOYMENT.git'
        BRANCH = 'main'
        FRONTEND_DIR = 'betech-login-frontend'
        BACKEND_DIR = 'betech-login-backend'
        DB_DIR = 'betech-postgresql-db'
        DOCKER_IMAGE_FRONTEND = 'betechinc/betech-app-deployment_betechnet-frontend'
        DOCKER_IMAGE_BACKEND = 'betechinc/betech-app-deployment_betechnet-backend'
        BUILD_NUMBER = 'v2.0'
        DOCKER_IMAGE_DB = 'betechinc/betech-app-deployment_betechnet-postgres'
        SONARQUBE_SERVER = 'SonarQubeServer'
        DOCKERHUB_CREDENTIALS = 'dockerhub-creds'
        NEXUS_URL = "http://172.31.35.139:8081"
        // Repository where we will upload the artifact
        NEXUS_REPOSITORY = "betech-login-backend"
        // Jenkins credential id to authenticate to Nexus OSS
        NEXUS_CREDENTIAL_ID = "nexus-creds"
        SLACK_CHANNEL = '#your-slack-channel'
        SLACK_CREDENTIALS = 'slack-token-id'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: "${BRANCH}", url: "${REPO_URL}"
            }
        }
        
        stage('Set POM File Distribution Managament') {
            steps {
                sh 'chmod +x append_distribution_management.sh'
                sh './append_distribution_management.sh'
            }
        }

        stage('Backend Test & Build Artifacts') {
            steps {
                dir("${BACKEND_DIR}") {
                    withMaven(globalMavenSettingsConfig: '', jdk: 'jdk11', maven: 'maven', mavenSettingsConfig: '', traceability: true) {
                        sh 'mvn clean test'
                        sh 'mvn clean package -DskipTests'
                    }
                }
            }
        }
        
        stage('Frontend Test & Build Artifacts') {
            steps {
                nodejs(nodeJSInstallationName: 'nodeJS') {
                    dir("${FRONTEND_DIR}") {
                        sh 'npm install'
                        sh 'npm install react-router-dom'
                        sh 'npm install -g sonar-scanner'
                        // sh 'npm run test'
                        sh 'npm run build'
                    }
                }
            }
        }

        stage('SonarQube Scan Backend') {
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
        
        stage('Backend OWASP Dependency-Check Scan') {
            steps {
                dir('${BACKEND_DIR}') {
                    dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                    dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                }
            }
        }
        
        stage('Backend Trivy File Scan') {
            steps {
                dir('${BACKEND_DIR}') {
                    sh 'trivy fs . > trivyfs.txt'
                }
            }
        }
        
        stage('SonarQube Scan Frontend') {
            steps {
                dir("${FRONTEND_DIR}") {
                    withSonarQubeEnv("${SONARQUBE_SERVER}") {
                        sh """
                            sonar-scanner \
                              -Dsonar.projectKey=betech-login-frontend \
                              -Dsonar.projectName=betech-login-frontend \
                              -Dsonar.sources=. \
                              -Dsonar.projectVersion=1.0
                        """
                    }
                }
            }
        }
        
        stage('Frontend OWASP Dependency-Check Scan') {
            steps {
                dir('${FRONTEND_DIR}') {
                    dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                    dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                }
            }
        }
        
        stage('Frontend Trivy File Scan') {
            steps {
                dir('${FRONTEND_DIR}') {
                    sh 'trivy fs . > trivyfs.txt'
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    sh 'docker system prune -f'
                    sh 'docker container prune -f'
                }
                dir("${FRONTEND_DIR}") {
                    script {
                        sh "docker build -t ${DOCKER_IMAGE_FRONTEND}:${BUILD_NUMBER} ."
                    }
                }
                dir("${BACKEND_DIR}") {
                    script {
                        sh "docker build -t ${DOCKER_IMAGE_BACKEND}:${BUILD_NUMBER} ."
                    }
                }
                dir("${DB_DIR}") {
                    script {
                        sh "docker build -t ${DOCKER_IMAGE_DB}:${BUILD_NUMBER} ."
                    }
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh "trivy image --exit-code 0 --severity HIGH,CRITICAL --format table -o betech-frontend-scan.html ${DOCKER_IMAGE_FRONTEND}:${BUILD_NUMBER}"
                sh "trivy image --exit-code 0 --severity HIGH,CRITICAL --format table -o betech-backend-scan.html ${DOCKER_IMAGE_BACKEND}:${BUILD_NUMBER}"
                sh "trivy image --exit-code 0 --severity HIGH,CRITICAL --format table -o betech-database-scan.html ${DOCKER_IMAGE_DB}:${BUILD_NUMBER}"
            }
        }
        
        stage('Publish Backend Artifact to Nexus') {
            steps {
                dir("${BACKEND_DIR}") {
                    withCredentials([usernamePassword(credentialsId: "${NEXUS_CREDENTIAL_ID}", usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                        sh """
                            mvn deploy -DskipTests \
                              -Dnexus.username=${NEXUS_USER} \
                              -Dnexus.password=${NEXUS_PASS}
                        """
                    }
                }
            }
        }
        
        // stage('Frontend Test & Build Artifacts') {
        //     steps {
        //         nodejs(nodeJSInstallationName: 'nodeJS') {
        //             dir("${FRONTEND_DIR}") {
        //                 sh """
        //                     npm set registry ${NEXUS_URL}/repository/betech-frontend-snapshot/
        //                     npm set //${NEXUS_URL#*//}/repository/betech-frontend-snapshot/:_auth \$(echo -n "$NEXUS_USER:$NEXUS_PASS" | base64)
        //                     npm set //${NEXUS_URL#*//}/repository/betech-frontend-snapshot/:always-auth true
        //                     npm publish
        //                 """
        //             }
        //         }
        //     }
        // }


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

        stage('Run docker-compose.yml') {
            steps {
                script {
                        sh "docker-compose up -d --build"
                }
            }
        }
    }

    // post {
    //     success {
    //         slackSend (
    //             channel: "${SLACK_CHANNEL}",
    //             color: '#36a64f',
    //             message: "Build #${BUILD_NUMBER} for ${env.JOB_NAME} succeeded! :tada:",
    //             tokenCredentialId: "${SLACK_CREDENTIALS}"
    //         )
    //     }
    //     failure {
    //         slackSend (
    //             channel: "${SLACK_CHANNEL}",
    //             color: '#FF0000',
    //             message: "Build #${BUILD_NUMBER} for ${env.JOB_NAME} failed! :x:",
    //             tokenCredentialId: "${SLACK_CREDENTIALS}"
    //         )
    //     }
    // }
}

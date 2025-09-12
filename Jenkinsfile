pipeline {
  agent any
  environment {
    IMAGE_NAME     = 'jenkins-go-app'
    IMAGE          = "jakirhosen9395/${IMAGE_NAME}"
    TAG            = "${env.BUILD_ID}"

    CODE_REPO      = 'git@github.com:jakirhosen9395/developer-repo.git'
    CODE_BRANCH    = 'go-app-develop'

    SCANNER_HOME   = tool 'sonar7.2'
    
    MANIFEST_REPO  = 'git@github.com:jakirhosen9395/deploy-repo.git'
    MANIFEST_BRANCH= 'k8s-manifest'
    MANIFEST_FILE  = 'go-app-cicd.yaml'
    
    CONTAINER_NAME  = 'jenkins-go-app'
    PORT_MAP        = '9001:9000'
    HOST            = 'root@192.168.56.51'
    SSH_CREDENTIALS = 'ssh-deploy-key'
  }

  stages {
    stage('Checkout source') {
      steps {
        git branch: "${CODE_BRANCH}", url: "${CODE_REPO}"
      }
    }

    stage('Unit test + Coverage') {
      steps {
        withEnv(["PATH+GO=/usr/local/go/bin"]) {
          sh '''
            go mod tidy
            go test ./... -coverprofile=coverage.out -covermode=atomic
            test -s coverage.out
          '''
        }
      }
    }

    stage('SonarQube Scan') {
      steps {
        withSonarQubeEnv('SonarQube-Server') {
          withEnv(["PATH+SCANNER=${SCANNER_HOME}/bin"]) {
            sh '''
              sonar-scanner \
                -Dsonar.projectKey=go-calculator \
                -Dsonar.projectName=go-calculator \
                -Dsonar.projectVersion=1.0 \
                -Dsonar.sourceEncoding=UTF-8 \
                -Dsonar.sources=. \
                -Dsonar.inclusions=**/*.go,**/*.html \
                -Dsonar.exclusions=**/vendor/**,**/*.gen.go \
                -Dsonar.tests=. \
                -Dsonar.test.inclusions=**/*_test.go \
                -Dsonar.go.coverage.reportPaths=coverage.out
            '''
          }
        }
      }
    }

    // stage('Quality Gate') {
    //   steps {
    //     timeout(time: 10, unit: 'MINUTES') {
    //       waitForQualityGate abortPipeline: false
    //     }
    //   }
    // }

    stage('Build image') {
      steps {
        sh '''
          test -f Dockerfile || cp /opt/docker/Dockerfile .
          docker build -t ${IMAGE}:${TAG} .
        '''
      }
    }

    stage('Docker Login') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
        }
      }
    }

    stage('Push image') {
      steps { sh 'docker push ${IMAGE}:${TAG}' }
    }

    stage('Update k8s manifest in deploy-repo') {
      steps {
        sshagent(credentials: ['github-ssh-key']) {
          sh '''
            rm -rf deploy-repo
            git clone -b ${MANIFEST_BRANCH} ${MANIFEST_REPO} deploy-repo
            cd deploy-repo

            sed -i -E 's#image:[[:space:]]*"?jakirhosen9395/'"${IMAGE_NAME}"':[^"[:space:]]*#image: "jakirhosen9395/'"${IMAGE_NAME}"':'"${TAG}"'#g' "${MANIFEST_FILE}"

            git config user.name "jenkins-bot"
            git config user.email "jenkins@local"
            git add "${MANIFEST_FILE}"
            git commit -m "update ${MANIFEST_FILE} image tag to ${TAG}" || true
            git push origin "${MANIFEST_BRANCH}"
          '''
        }
      }
    }
    stage('Deploy from Docker Hub') {
        steps {
            sshagent(credentials: [SSH_CREDENTIALS]) {
                sh "ssh -o StrictHostKeyChecking=no ${HOST} 'docker rm -f ${CONTAINER_NAME} && docker pull ${IMAGE}:${TAG} && docker run -d --name ${CONTAINER_NAME} -p ${PORT_MAP} --restart always -e HOST=0.0.0.0 -e PORT=9000 ${IMAGE}:${TAG}'"
            }
          }
        }
    }
}

// =============================================================================
// hello-cicd — Jenkins CI (enterprise-faithful)
//
//   checkout → login JFrog → stamp build version into the page
//           → build (base pulled THROUGH JFrog) → push tagged image to JFrog
//           → STOP (deploy is a manual tag bump in the gitops repo → ArgoCD)
//
// Prereqs on the Jenkins VM:
//   - Docker available to the jenkins user
//   - Jenkins credential 'jfrog-docker' (username + token)  ← matches JFROG_CREDS
//   - edit the env{} block to your real JFrog subdomain
// =============================================================================
pipeline {
  agent any

  environment {
    JFROG_HOST     = 'triald3uyq5.jfrog.io'                          // ← your JFrog Cloud host
    JFROG_VIRTUAL  = "${JFROG_HOST}/sample-docker"        // base-image proxy
    JFROG_APP_REPO = "${JFROG_HOST}/sample-docker"          // built images go here
    IMAGE_NAME     = 'hello-cicd'
    JFROG_CREDS    = 'jfrog-docker'
  }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.GIT_SHA   = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_SHA}"   // immutable, traceable
          echo "Image tag: ${env.IMAGE_TAG}"
        }
      }
    }

    stage('Stamp build version') {
      steps {
        // make each deploy visibly distinct in the browser
        sh 'sed -i "s/__BUILD_VERSION__/${IMAGE_TAG}/" index.html'
      }
    }

    stage('Login to JFrog') {
      steps {
        withCredentials([usernamePassword(credentialsId: env.JFROG_CREDS,
            usernameVariable: 'JF_USER', passwordVariable: 'JF_PASS')]) {
          sh 'echo "$JF_PASS" | docker login "$JFROG_HOST" -u "$JF_USER" --password-stdin'
        }
      }
    }

    stage('Build (base from JFrog)') {
      steps {
        sh '''
          docker build \
            --build-arg REGISTRY="${JFROG_VIRTUAL}/" \
            -t "${JFROG_APP_REPO}/${IMAGE_NAME}:${IMAGE_TAG}" \
            -t "${JFROG_APP_REPO}/${IMAGE_NAME}:latest" \
            .
        '''
      }
    }

    stage('Push to JFrog') {
      steps {
        sh '''
          docker push "${JFROG_APP_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"
          docker push "${JFROG_APP_REPO}/${IMAGE_NAME}:latest"
        '''
      }
    }

    stage('Ready for manual promotion') {
      steps {
        echo """
        =====================================================================
        PUBLISHED:  ${JFROG_APP_REPO}/${IMAGE_NAME}:${IMAGE_TAG}

        Promote (manual):
          edit gitops repo  apps/hello-cicd/deployment.yaml
            image: ...:${IMAGE_TAG}
          git commit && push  →  ArgoCD deploys.
        =====================================================================
        """
      }
    }
  }

  post {
    always {
      sh '''
        docker rmi "${JFROG_APP_REPO}/${IMAGE_NAME}:${IMAGE_TAG}" || true
        docker rmi "${JFROG_APP_REPO}/${IMAGE_NAME}:latest" || true
        docker logout "${JFROG_HOST}" || true
      '''
    }
  }
}

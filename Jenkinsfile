// =============================================================================
// hello-cicd — Jenkins CI (parameterized by RELEASE_NUMBER)
//
//   You run the job with RELEASE_NUMBER = 120 (or 121, 122, ...).
//   Jenkins builds the image and tags it EXACTLY that release number, then
//   pushes to JFrog. No manual `docker tag` afterward — Jenkins owns the tag.
//
//   To promote a release into an environment, edit that env's values file:
//     charts/hello-cicd/values-idevN.yaml  →  image.tag: "<RELEASE_NUMBER>"
//   commit + push the gitops repo → ArgoCD deploys it.
//
// Prereqs on the Jenkins VM:
//   - Docker available to the jenkins user
//   - Jenkins credential 'jfrog-docker' (username + token)
// =============================================================================
pipeline {
  agent any

  parameters {
    string(
      name: 'RELEASE_NUMBER',
      defaultValue: '120',
      description: 'The release number to build and tag (e.g. 120, 121, 122). This becomes the image tag.'
    )
  }

  environment {
    JFROG_HOST     = 'triald3uyq5.jfrog.io'
    JFROG_VIRTUAL  = "${JFROG_HOST}/sample-docker"     // base-image proxy
    JFROG_APP_REPO = "${JFROG_HOST}/sample-docker"     // built images go here
    IMAGE_NAME     = 'hello-cicd'
    JFROG_CREDS    = 'jfrog-docker'
  }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  stages {
    stage('Validate input') {
      steps {
        script {
          if (!params.RELEASE_NUMBER?.trim()) {
            error "RELEASE_NUMBER is required (e.g. 120)."
          }
          // the release number IS the image tag — immutable, meaningful
          env.IMAGE_TAG = params.RELEASE_NUMBER.trim()
          echo "Building release ${env.IMAGE_TAG} → ${env.JFROG_APP_REPO}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
        }
      }
    }

    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.GIT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          echo "Source commit: ${env.GIT_SHA}"
        }
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
        // The page now renders ENVIRONMENT + RELEASE from env vars at startup,
        // so the image itself is environment-agnostic — the SAME image serves
        // every idev env; the Helm values inject the per-env identity.
        sh '''
          docker build \
            --build-arg REGISTRY="${JFROG_VIRTUAL}/" \
            -t "${JFROG_APP_REPO}/${IMAGE_NAME}:${IMAGE_TAG}" \
            .
        '''
      }
    }

    stage('Push to JFrog') {
      steps {
        sh 'docker push "${JFROG_APP_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"'
      }
    }

    stage('Done') {
      steps {
        echo """
        =====================================================================
        PUBLISHED:  ${JFROG_APP_REPO}/${IMAGE_NAME}:${IMAGE_TAG}
                    (built from commit ${GIT_SHA})

        Promote into an environment (manual, in the gitops repo):
          charts/hello-cicd/values-idevN.yaml →  image.tag: "${IMAGE_TAG}"
          git commit && push  →  ArgoCD deploys ONLY that environment.
        =====================================================================
        """
      }
    }
  }

  post {
    always {
      sh '''
        docker rmi "${JFROG_APP_REPO}/${IMAGE_NAME}:${IMAGE_TAG}" || true
        docker logout "${JFROG_HOST}" || true
      '''
    }
  }
}

import java.util.Date

// =============================================================================
// hello-cicd — Jenkins CI, built in the HHS RAE pattern.
//
//   The image TAG is the Jenkins BUILD_NUMBER (auto-incrementing) — every build
//   is uniquely numbered by Jenkins itself. ReleaseNumber selects the git BRANCH
//   to build (not the tag). Images are pushed to JFrog as:
//       <JFROG_URL>/<REPO_NAME>/<IMAGE_NAME>:<BUILD_NUMBER>
//
//   To promote a build into an environment, edit that env's values file:
//       environments/idevN/values.yaml  ->  image.tag: "<BUILD_NUMBER>"
//   commit + push the gitops repo -> ArgoCD deploys ONLY that environment.
// =============================================================================

// One entry per source repo. Exactly one must have isMain:true. For this lab
// there is a single app repo; Jenkins checks it out into the workspace via
// `checkout scm` (the job's configured Git repo/branch), so no path is needed.
def projectReposFor = { String releaseNumber ->
  [
    [name: 'hello-cicd', isMain: true],
  ]
}

pipeline {
    agent any

    parameters {
        string(name: 'ReleaseNumber',        defaultValue: 'main', description: 'Git branch to build (e.g. main, REL-1.2). Selects the branch, NOT the tag.')
        string(name: 'ReleaseBranchPrefix',  defaultValue: '/REL', description: 'Branch prefix')
        booleanParam(name: 'ForceBuild',     defaultValue: true,  description: 'Force Build')
        booleanParam(name: 'SKIP_GIT_TAG',   defaultValue: false, description: 'Skip tagging + metadata')
    }

    environment {
        JFROG_URL       = 'triald3uyq5.jfrog.io'
        REPO_NAME       = 'sample-docker'
        IMAGE_NAME      = 'hello-cicd'
        TAG             = "${env.BUILD_NUMBER}"                       // <-- the build number IS the tag
        FULL_IMAGE_PATH = "${JFROG_URL}/${REPO_NAME}/${IMAGE_NAME}:${TAG}"
        JFROG_CREDS     = 'jfrog-docker'                             // Jenkins username+token credential
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    stages {
        stage('Checkout') {
          // Single Jenkins instance (no agents): the build runs on the controller
          // and checks the repo out into the JOB WORKSPACE. This guarantees we
          // build the LATEST commit of the configured branch every time.
          steps {
            script {
              def relNum = params.ReleaseNumber?.trim()
              if (!relNum) error("ReleaseNumber is required")

              def repos = projectReposFor(relNum)
              def mainRepos = repos.findAll { it.isMain == true }
              if (mainRepos.size() != 1) error("Exactly one repo must have isMain: true")
              def mainRepo = mainRepos[0]

              // pull the job's configured repo/branch into the workspace:
              checkout scm

              env.MAIN_DIR = "${env.WORKSPACE}"        // build from the workspace root
              env.GIT_SHA  = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
              env.GIT_BRANCH_NAME = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
              echo "${mainRepo.name} checked out @ ${env.GIT_SHA} (${env.GIT_BRANCH_NAME})"
              echo "Building ${env.FULL_IMAGE_PATH} from commit ${env.GIT_SHA}"
            }
          }
        }

        stage('Build and Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.JFROG_CREDS,
                    usernameVariable: 'JF_USER', passwordVariable: 'JF_PASS')]) {
                    sh """#!/bin/bash
                        set -euo pipefail
                        echo "\$JF_PASS" | docker login ${JFROG_URL} -u "\$JF_USER" --password-stdin
                        DOCKER_BUILDKIT=0 docker build -t ${FULL_IMAGE_PATH} -f Dockerfile .
                        docker push ${FULL_IMAGE_PATH}
                    """
                }
            }
        }

        stage('Done') {
            steps {
                echo """
                =====================================================================
                PUBLISHED:  ${FULL_IMAGE_PATH}
                            (built from commit ${GIT_SHA}, branch ${ReleaseNumber})
                Promote into an environment (manual, in the gitops repo):
                  environments/idevN/values.yaml  ->  image.tag: "${TAG}"
                  git commit && push  ->  ArgoCD deploys ONLY that environment.
                =====================================================================
                """
            }
        }
    }

    post {
        always {
            sh """
                docker rmi ${FULL_IMAGE_PATH} || true
                docker logout ${JFROG_URL} || true
            """
        }
    }
}

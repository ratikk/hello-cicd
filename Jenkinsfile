import java.util.Date

// =============================================================================
// hello-cicd — Jenkins CI, pushing to Amazon ECR.
//
//   The image TAG is the Jenkins BUILD_NUMBER (auto-incrementing). Images push to
//   ECR at:  <ACCOUNT>.dkr.ecr.<REGION>.amazonaws.com/hello-cicd:<BUILD_NUMBER>
//
//   AUTH: the Jenkins EC2's IAM instance role (hub-jenkins-demo-role) has ECR
//   push permission, so we authenticate with `aws ecr get-login-password` —
//   NO stored Jenkins credential needed. Short-lived token, fetched per build.
//
//   ECR serves plain Docker v2 manifests by tag AND digest reliably (unlike the
//   JFrog trial), so digests pinned in Git will actually pull on CRI-O.
//
//   To promote a build into an environment, edit that env's values file:
//       environments/idevN/values.yaml  ->  image.tag/digest
//   commit + push the gitops repo -> ArgoCD deploys ONLY that environment.
// =============================================================================

def projectReposFor = { String releaseNumber ->
  [
    [name: 'hello-cicd', isMain: true],
  ]
}

pipeline {
    agent any

    parameters {
        string(name: 'ReleaseNumber',       defaultValue: 'main', description: 'Git branch to build (e.g. main). Selects the branch, NOT the tag.')
        string(name: 'ReleaseBranchPrefix', defaultValue: '/REL', description: 'Branch prefix')
        booleanParam(name: 'ForceBuild',    defaultValue: true,  description: 'Force Build')
        booleanParam(name: 'SKIP_GIT_TAG',  defaultValue: false, description: 'Skip tagging + metadata')
    }

    environment {
        AWS_REGION      = 'us-east-1'
        ECR_REGISTRY    = '025037641706.dkr.ecr.us-east-1.amazonaws.com'
        IMAGE_NAME      = 'hello-cicd'
        TAG             = "${env.BUILD_NUMBER}"                      // build number IS the tag
        FULL_IMAGE_PATH = "${ECR_REGISTRY}/${IMAGE_NAME}:${TAG}"
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    stages {
        stage('Checkout') {
          steps {
            script {
              def relNum = params.ReleaseNumber?.trim()
              if (!relNum) error("ReleaseNumber is required")

              def repos = projectReposFor(relNum)
              def mainRepos = repos.findAll { it.isMain == true }
              if (mainRepos.size() != 1) error("Exactly one repo must have isMain: true")
              def mainRepo = mainRepos[0]

              checkout scm

              env.MAIN_DIR = "${env.WORKSPACE}"
              env.GIT_SHA  = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
              env.GIT_BRANCH_NAME = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
              echo "${mainRepo.name} checked out @ ${env.GIT_SHA} (${env.GIT_BRANCH_NAME})"
              echo "Building ${env.FULL_IMAGE_PATH} from commit ${env.GIT_SHA}"
            }
          }
        }

        stage('Build and Push') {
            steps {
                sh """#!/bin/bash
                    set -euo pipefail
                    # authenticate to ECR using the EC2 instance role (no stored creds):
                    aws ecr get-login-password --region ${AWS_REGION} \
                      | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    DOCKER_BUILDKIT=0 docker build -t ${FULL_IMAGE_PATH} -f Dockerfile .
                    docker push ${FULL_IMAGE_PATH}
                """
            }
        }

        stage('Done') {
            steps {
                echo """
                =====================================================================
                PUBLISHED:  ${FULL_IMAGE_PATH}
                            (built from commit ${GIT_SHA}, branch ${ReleaseNumber})
                Fetch the pullable digest (ECR serves by digest reliably):
                  aws ecr describe-images --repository-name ${IMAGE_NAME} \\
                    --region ${AWS_REGION} --image-ids imageTag=${TAG} \\
                    --query 'imageDetails[0].imageDigest' --output text
                Promote: environments/idevN/values.yaml -> that tag + digest, commit, push.
                =====================================================================
                """
            }
        }
    }

    post {
        always {
            sh """
                docker rmi ${FULL_IMAGE_PATH} || true
                docker logout ${ECR_REGISTRY} || true
            """
        }
    }
}

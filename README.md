# hello-cicd

Minimal app to prove the CI/CD chain: **Jenkins → JFrog → (manual tag bump) → ArgoCD → OpenShift**.

- `Dockerfile`, `index.html`, `nginx.conf` — the trivial nginx app Jenkins builds
- `Jenkinsfile` — the CI pipeline (build base from JFrog, build, push to `sample-docker`)

The deploy half (Deployment/Service/Route + ArgoCD Application) lives in the gitops repo
`ratikk/openshift-rae-gitops` under `apps/hello-cicd/`.

Image: `triald3uyq5.jfrog.io/sample-docker/hello-cicd:<build>-<sha>`

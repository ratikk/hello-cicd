# =============================================================================
# hello-cicd — minimal image to prove the CI/CD chain.
#
# Pulls the nginx BASE image FROM JFrog (the virtual repo proxying Docker Hub),
# copies one static page in, serves it. No build tooling — the point is the
# pipeline, not the app.
#
#   docker build --build-arg REGISTRY=<host>/<virtual-repo>/ -t <image:tag> .
#
# REGISTRY (with trailing slash) makes the base pull come THROUGH JFrog.
# Empty REGISTRY → falls back to Docker Hub.
# =============================================================================
ARG REGISTRY=
FROM ${REGISTRY}nginx:1.27-alpine

# the static page + SPA-friendly nginx conf (listens on 8080 for non-root)
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

# OpenShift runs containers as a random high UID — make the dirs group-writable
RUN chgrp -R 0 /var/cache/nginx /var/run /usr/share/nginx/html /etc/nginx/conf.d \
 && chmod -R g=u /var/cache/nginx /var/run /usr/share/nginx/html /etc/nginx/conf.d

USER 1001
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]

ARG REGISTRY=
FROM ${REGISTRY}nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
# store as a TEMPLATE; entrypoint renders env vars into /tmp/html at startup
COPY index.html /usr/share/nginx/html/index.html.tmpl
COPY docker-entrypoint.sh /docker-entrypoint-custom.sh

RUN chmod +x /docker-entrypoint-custom.sh \
 && chgrp -R 0 /var/cache/nginx /var/run /etc/nginx/conf.d \
 && chmod -R g=u /var/cache/nginx /var/run /etc/nginx/conf.d

USER 1001
EXPOSE 8080
ENTRYPOINT ["/docker-entrypoint-custom.sh"]

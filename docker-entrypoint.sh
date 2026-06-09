#!/bin/sh
# Render ENVIRONMENT + RELEASE into the page at startup. Write to /tmp (always
# writable by OpenShift's arbitrary UID) and serve from there — avoids the
# "random UID can't write /usr/share/nginx/html" gotcha.
set -e
: "${ENVIRONMENT:=unknown}"
: "${RELEASE:=unknown}"
mkdir -p /tmp/html
sed "s/__ENVIRONMENT__/${ENVIRONMENT}/g; s/__RELEASE__/${RELEASE}/g" \
  /usr/share/nginx/html/index.html.tmpl > /tmp/html/index.html
exec nginx -g 'daemon off;'

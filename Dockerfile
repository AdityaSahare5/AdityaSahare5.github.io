# Staging container. Uses the unprivileged nginx image:
# runs as a non-root user and listens on 8080 (a common hardening step).
FROM nginxinc/nginx-unprivileged:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY dist/ /usr/share/nginx/html/

EXPOSE 8080
HEALTHCHECK CMD wget -qO- http://localhost:8080/ || exit 1

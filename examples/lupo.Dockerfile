# syntax=docker/dockerfile:1.7
#
# Example Lupo Dockerfile using canis-base-tools

FROM ghcr.io/datacite/canis-base-tools:v1.2.3

LABEL maintainer="support@datacite.org"

ENV NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/sites-enabled

# Lupo-specific nginx configuration
COPY vendor/docker/webapp.conf.template /etc/nginx/templates/webapp.conf.template
COPY vendor/docker/70_nginx_templates.sh /etc/my_init.d/70_nginx_templates.sh

# Passenger metrics (requires AWS CLI from the tools image)
RUN mkdir -p /etc/service/passenger-metrics
COPY vendor/docker/passenger-metrics-run.sh /etc/service/passenger-metrics/run

# Standard service and startup scripts
COPY vendor/docker/00_app_env.conf /etc/nginx/conf.d/00_app_env.conf
COPY vendor/docker/ntp.conf /etc/ntp.conf

RUN mkdir -p /etc/service/shoryuken
COPY vendor/docker/shoryuken.sh /etc/service/shoryuken/run

COPY vendor/docker/10_ssh.sh /etc/my_init.d/10_ssh.sh
COPY vendor/docker/90_migrate.sh /etc/my_init.d/90_migrate.sh

# Application code
COPY . /home/app/webapp/
RUN mkdir -p tmp/pids tmp/storage && \
    chown -R app:app /home/app/webapp && \
    chmod -R 755 /home/app/webapp

# Install gems
WORKDIR /home/app/webapp
RUN mkdir -p vendor/bundle && \
    chown -R app:app . && \
    /sbin/setuser app bundle config set --local path 'vendor/bundle' && \
    /sbin/setuser app bundle install

EXPOSE 80

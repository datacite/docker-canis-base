# syntax=docker/dockerfile:1.7
#
# Example Lupo Dockerfile using canis-base
# Base already provides: passenger/nginx, app_env, ntp, root SSH, guarded shoryuken
# Lupo-only ops (Percona, AWS CLI, metrics, templates) stay in this Dockerfile

FROM ghcr.io/datacite/canis-base:1.2.3

LABEL maintainer="support@datacite.org"

ENV NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/sites-enabled

# Lupo-only packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      default-libmysqlclient-dev imagemagick gettext \
      gnupg lsb-release unzip \
      libdbd-mysql-perl libdbi-perl libterm-readkey-perl libio-socket-ssl-perl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG PERCONA_TOOLKIT_VERSION=3.7.1-3.noble

# Percona Toolkit (Lupo only)
RUN wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends ./percona-release_latest.generic_all.deb && \
    percona-release enable pt release && \
    apt-get update && \
    apt-get install -y --no-install-recommends percona-toolkit=${PERCONA_TOOLKIT_VERSION} && \
    apt-mark hold percona-toolkit && \
    rm -f percona-release_latest.generic_all.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# AWS CLI v2 (Lupo passenger metrics / scaling)
RUN wget -q https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -O /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/awscliv2.zip /tmp/aws

# Lupo-specific nginx configuration
COPY vendor/docker/webapp.conf.template /etc/nginx/templates/webapp.conf.template
COPY vendor/docker/70_nginx_templates.sh /etc/my_init.d/70_nginx_templates.sh

# Passenger metrics
RUN mkdir -p /etc/service/passenger-metrics
COPY vendor/docker/passenger-metrics-run.sh /etc/service/passenger-metrics/run

# Migrations stay in the app (not in the base)
COPY vendor/docker/90_migrate.sh /etc/my_init.d/90_migrate.sh

# Application code
COPY . /home/app/webapp/
RUN mkdir -p tmp/pids tmp/storage && \
    chown -R app:app /home/app/webapp && \
    chmod -R 755 /home/app/webapp

WORKDIR /home/app/webapp
RUN mkdir -p vendor/bundle && \
    chown -R app:app . && \
    /sbin/setuser app bundle config set --local path 'vendor/bundle' && \
    /sbin/setuser app bundle install

EXPOSE 80

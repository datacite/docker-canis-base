# syntax=docker/dockerfile:1.7
#
# Example Lupo Dockerfile using canis-base-tools
# Base already provides: passenger/nginx, app_env, ntp, root SSH, guarded shoryuken

FROM ghcr.io/datacite/canis-base-tools:1.2.3

LABEL maintainer="support@datacite.org"

ENV NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/sites-enabled

# Lupo-only packages (not in the shared base)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      default-libmysqlclient-dev imagemagick gettext && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Lupo-specific nginx configuration
COPY vendor/docker/webapp.conf.template /etc/nginx/templates/webapp.conf.template
COPY vendor/docker/70_nginx_templates.sh /etc/my_init.d/70_nginx_templates.sh

# Passenger metrics (requires AWS CLI from the tools image)
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

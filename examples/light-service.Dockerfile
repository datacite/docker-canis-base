# syntax=docker/dockerfile:1.7
#
# Example for a Canis service using only the slim core base
# (e.g. events, levriero, sashimi, volpino — after Ruby 4)
# Base already provides: passenger/nginx, app_env, ntp, root SSH, guarded shoryuken

FROM ghcr.io/datacite/canis-base:1.2.3

LABEL maintainer="support@datacite.org"

# Service-only packages (examples)
# RUN apt-get update && apt-get install -y --no-install-recommends \
#       default-libmysqlclient-dev imagemagick && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*

COPY vendor/docker/webapp.conf /etc/nginx/sites-enabled/webapp.conf

# Optional: enable migrations on boot (kept in the app, not the base)
# COPY vendor/docker/90_migrate.sh /etc/my_init.d/90_migrate.sh

# Optional: override base shoryuken/ssh/app_env only if this service differs
# COPY vendor/docker/shoryuken.sh /etc/service/shoryuken/run

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

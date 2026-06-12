# syntax=docker/dockerfile:1.7
#
# Example for a lighter service using only the slim core base

FROM ghcr.io/datacite/canis-base:v1.2.3

LABEL maintainer="support@datacite.org"

# Add only what is unique to your service here
COPY vendor/docker/webapp.conf /etc/nginx/sites-enabled/webapp.conf
COPY vendor/docker/00_app_env.conf /etc/nginx/conf.d/00_app_env.conf

RUN mkdir -p /etc/service/shoryuken
COPY vendor/docker/shoryuken.sh /etc/service/shoryuken/run

COPY vendor/docker/10_ssh.sh /etc/my_init.d/10_ssh.sh
COPY vendor/docker/90_migrate.sh /etc/my_init.d/90_migrate.sh

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

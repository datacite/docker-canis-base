# syntax=docker/dockerfile:1.7
#
# DataCite Canis Base Image (slim core)
#
# This is the minimal shared base used by all services.
# Heavy operational tools live in Dockerfile.tools.

FROM phusion/passenger-ruby40:3.1.6

LABEL maintainer="support@datacite.org" \
      org.opencontainers.image.source="https://github.com/datacite/docker-canis-base" \
      org.opencontainers.image.description="DataCite Canis Base (slim core)"

ENV HOME=/home/app \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/sites-enabled \
    DEBIAN_FRONTEND=noninteractive

# ============================================================================
# Core system packages + native gem build dependencies
# ============================================================================
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
    apt-get install -y --no-install-recommends \
      # Common operational / debugging tools
      ntp wget ca-certificates gnupg tzdata shared-mime-info \
      nano tmux gettext unzip libxml2-utils imagemagick git curl jq \
      lsb-release \
      # Critical for Rails native extensions (mysql2, nokogiri, etc.)
      build-essential default-libmysqlclient-dev libxslt1-dev \
      libyaml-dev zlib1g-dev pkg-config \
      # Graphics / image processing libs (for rmagick, vips, etc.)
      libpng-dev libjpeg-dev libcairo2-dev libfreetype6-dev fontconfig \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================================
# User permissions + git safety
# ============================================================================
RUN usermod -a -G docker_env app && \
    git config --global --add safe.directory /home/app/webapp

# ============================================================================
# Ruby 4 + modern Bundler baseline
# ============================================================================
RUN bash -lc 'rvm --default use ruby-4.0.1 && gem install rubygems-update -v 3.5.6 && gem install bundler -v 2.6.9'

# ============================================================================
# Standard Phusion layout
# ============================================================================
RUN rm -f /etc/service/nginx/down && \
    rm -f /etc/nginx/sites-enabled/default && \
    mkdir -p /etc/nginx/templates /etc/service/shoryuken /etc/my_init.d /etc/nginx/conf.d

# Copy common configuration and scripts from the base repo's vendor/docker/.
# These match the layout used in other DataCite repos (lupo, levriero, etc.).
# Apps can still override any of these by COPY-ing their own version later in their Dockerfile.
COPY vendor/docker/ntp.conf /etc/ntp.conf
COPY vendor/docker/00_app_env.conf /etc/nginx/conf.d/00_app_env.conf
COPY vendor/docker/10_ssh.sh /etc/my_init.d/10_ssh.sh
COPY vendor/docker/90_migrate.sh /etc/my_init.d/90_migrate.sh
COPY vendor/docker/shoryuken.sh /etc/service/shoryuken/run

# Make sure init scripts are executable
RUN chmod +x /etc/my_init.d/10_ssh.sh \
             /etc/my_init.d/90_migrate.sh \
             /etc/service/shoryuken/run

WORKDIR /home/app/webapp
CMD ["/sbin/my_init"]
EXPOSE 80

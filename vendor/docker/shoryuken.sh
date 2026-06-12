#!/bin/sh
set -e

# Standard Shoryuken runner for DataCite services
exec /sbin/setuser app bundle exec shoryuken -R -C config/shoryuken.yml

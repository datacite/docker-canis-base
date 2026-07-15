#!/bin/sh
cd /home/app/webapp
exec 2>&1
# Start only in AWS; allow opt-out with DISABLE_QUEUE_WORKER (e.g. local compose)
if [ -n "$AWS_REGION" ] && [ -z "$DISABLE_QUEUE_WORKER" ]; then
  exec /sbin/setuser app bundle exec shoryuken -R -C config/shoryuken.yml
fi

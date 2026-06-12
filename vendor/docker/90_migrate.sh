#!/bin/bash
set -e

echo "Running database migrations as app user..."
exec /sbin/setuser app bundle exec rake db:migrate

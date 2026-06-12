#!/bin/bash
set -e

# Install custom SSH key during startup (from environment or secret)
if [ -n "$SSH_PUBLIC_KEY" ]; then
  mkdir -p /home/app/.ssh
  echo "$SSH_PUBLIC_KEY" > /home/app/.ssh/authorized_keys
  chown -R app:app /home/app/.ssh
  chmod 700 /home/app/.ssh
  chmod 600 /home/app/.ssh/authorized_keys
  echo "SSH key installed for app user"
fi

# Enable SSH service (Phusion base has it disabled by default)
rm -f /etc/service/sshd/down || true

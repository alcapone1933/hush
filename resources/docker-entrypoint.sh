#!/bin/bash
set -x
# Get the PUID and PGID from environment variables (or use default values 1000 if not set)
PUID=${PUID:-1000}
PGID=${PGID:-1000}
TZ=${TZ:-Europe/Berlin}

ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Check if the provided PUID and PGID are non-empty, numeric values; otherwise, assign default values.
if ! [[ "$PUID" =~ ^[0-9]+$ ]]; then
  PUID=1000
fi
if ! [[ "$PGID" =~ ^[0-9]+$ ]]; then
  PGID=1000
fi
# Check if the specified group with PGID exists, if not, create it.
if ! getent group "$PGID" >/dev/null; then
  groupadd -g "$PGID" appgroup
fi
# Create user.
useradd --create-home --shell /bin/bash --uid "$PUID" --gid "$PGID" appuser
# Make matplotlib cache folder.
mkdir -p /app/mpl
# Make user the owner of the app directory.
chown -R appuser:appgroup /app
# Copy the default .bashrc file to the appuser home directory.
mkdir -p /home/appuser/.ssh
chown appuser:appgroup /home/appuser/.ssh
cp /etc/skel/.bashrc /home/appuser/.bashrc
chown appuser:appgroup /home/appuser/.bashrc
export HOME=/home/appuser
# Set permissions on font directories.
if [ -d "/usr/share/fonts" ]; then
  chmod -R 777 /usr/share/fonts
fi
if [ -d "/var/cache/fontconfig" ]; then
  chmod -R 777 /var/cache/fontconfig
fi
if [ -d "/usr/local/share/fonts" ]; then
  chmod -R 777 /usr/local/share/fonts
fi

# Switch to appuser and execute the Docker CMD or passed in command-line arguments.
# Using setpriv let's it run as PID 1 which is required for proper signal handling (similar to gosu/su-exec).
exec setpriv --reuid=$PUID --regid=$PGID --init-groups $@
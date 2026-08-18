#!/bin/sh
set -eu

cd /srv/webvirtcloud

DATA_DIR=/var/lib/webvirtcloud
SETTINGS=webvirtcloud/settings.py

mkdir -p "$DATA_DIR" /run/nginx /var/log/nginx /var/lib/nginx

# Create settings.py from the upstream template on first boot.
if [ ! -f "$SETTINGS" ]; then
    cp webvirtcloud/settings.py.template "$SETTINGS"
fi

if grep -q 'SECRET_KEY = ""' "$SETTINGS"; then
    /usr/local/bin/wvc-config.py
fi

echo "Running database migrations..."
venv/bin/python manage.py migrate --noinput

echo "Collecting static files..."
venv/bin/python manage.py collectstatic --noinput

# The baseimage creates the runtime user from USER_ID/GROUP_ID before init
# scripts run. Make application-owned paths writable by that user.
if [ -f /srv/webvirtcloud/webvirtcloud.log ]; then
    chown app:app /srv/webvirtcloud/webvirtcloud.log
fi
chown -R app:app "$DATA_DIR" /run/nginx /var/lib/nginx /var/log/nginx

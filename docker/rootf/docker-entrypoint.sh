#!/bin/sh
set -eu

cd /srv/webvirtcloud

DATA_DIR=/var/lib/webvirtcloud
mkdir -p "$DATA_DIR"

SETTINGS=webvirtcloud/settings.py

# Create settings.py from the upstream template on first boot.
if [ ! -f "$SETTINGS" ]; then
    cp webvirtcloud/settings.py.template "$SETTINGS"
fi

# Only auto-configure when this is still the untouched template, so a
# user-provided / mounted settings.py is always respected.
if grep -q 'SECRET_KEY = ""' "$SETTINGS"; then
    /usr/local/bin/wvc-config.py
fi

echo "Running database migrations..."
venv/bin/python manage.py migrate --noinput

echo "Collecting static files..."
venv/bin/python manage.py collectstatic --noinput

# The steps above run as root and may have created files owned by root
# (e.g. the webvirtcloud.log that Django's logging opens, or the sqlite db).
# The runtime services (gunicorn/novnc/socketiod) run as www-data, so the
# files they must write need to be owned by www-data. We only chown the
# specific paths root writes to (NOT the whole /srv tree, which is huge and
# chowning it on overlay filesystems is extremely slow / can stall).
if [ -f /srv/webvirtcloud/webvirtcloud.log ]; then
    chown www-data:www-data /srv/webvirtcloud/webvirtcloud.log
fi
chown -R www-data:www-data "$DATA_DIR"

# If the host libvirt socket is mounted, let the runtime user (www-data) open
# it. supervisord drops privileges with initgroups(), which would otherwise
# reset the process groups to www-data's container groups and drop the GID
# supplied via docker's group_add. Creating the group locally (with the host
# libvirt GID) and adding www-data to it makes the access survive the drop.
if [ -n "${LIBVIRT_GID:-}" ]; then
    if ! getent group "${LIBVIRT_GID}" >/dev/null 2>&1; then
        groupadd -g "${LIBVIRT_GID}" libvirt_host 2>/dev/null || true
    fi
    usermod -aG libvirt_host www-data 2>/dev/null || true
fi

exec "$@"

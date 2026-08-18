#!/bin/sh
set -eu

cd /srv/webvirtcloud

exec /srv/webvirtcloud/venv/bin/gunicorn \
    webvirtcloud.wsgi:application \
    -c /srv/webvirtcloud/gunicorn.conf.py

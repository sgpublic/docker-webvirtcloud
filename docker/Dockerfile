FROM jlesage/baseimage:ubuntu-24.04-v3

ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/srv/webvirtcloud/venv/bin:$PATH

# nginx package scripts expect the traditional www-data account.  The
# baseimage generates /etc/passwd dynamically, so define this account before
# installing packages that reference it.
COPY docker/rootf/etc/cont-users.d /etc/cont-users.d

RUN /opt/base/bin/add-pkg \
        ca-certificates \
        python3 \
        python3-venv \
        python3-dev \
        python3-lxml \
        libvirt-dev \
        zlib1g-dev \
        libxslt1-dev \
        libsasl2-dev \
        libsasl2-modules \
        libldap2-dev \
        libssl-dev \
        pkg-config \
        gcc \
        nginx \
        passwd

# WebVirtCloud upstream submodule
COPY webvirtcloud/ /srv/webvirtcloud/

WORKDIR /srv/webvirtcloud

# Python environment
RUN python3 -m venv venv \
    && venv/bin/pip install --no-cache-dir --upgrade pip wheel \
    && venv/bin/pip install --no-cache-dir -r conf/requirements.txt \
    && venv/bin/pip install --no-cache-dir psycopg2-binary

# Build/runtime helpers (initialization script, services, settings generator)
COPY docker/rootf/ /

# nginx
RUN rm -f /etc/nginx/sites-enabled/default \
    && cp conf/nginx/webvirtcloud.conf /etc/nginx/conf.d/webvirtcloud.conf

# Persistent data dir (secret key, sqlite fallback db, logs).  Ownership is
# applied by the baseimage initialization script because USER_ID/GROUP_ID are
# runtime settings.
RUN mkdir -p /var/lib/webvirtcloud /run/nginx \
    && chmod +x \
        /etc/cont-init.d/50-webvirtcloud.sh \
        /etc/services.d/novncd/run \
        /etc/services.d/socketiod/run \
        /etc/services.d/nginx/run \
        /startapp.sh \
        /usr/local/bin/wvc-config.py

VOLUME /var/lib/webvirtcloud

EXPOSE 80

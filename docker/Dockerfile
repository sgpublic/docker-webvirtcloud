FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/srv/webvirtcloud/venv/bin:$PATH

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
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
        supervisor \
        passwd \
    && rm -rf /var/lib/apt/lists/*

# WebVirtCloud upstream submodule
COPY webvirtcloud/ /srv/webvirtcloud/

# Build/runtime helpers (entrypoint, supervisor config, settings generator)
COPY docker/rootf/ /

WORKDIR /srv/webvirtcloud

# Python environment
RUN python3 -m venv venv \
    && venv/bin/pip install --no-cache-dir --upgrade pip wheel \
    && venv/bin/pip install --no-cache-dir -r conf/requirements.txt \
    && venv/bin/pip install --no-cache-dir psycopg2-binary

# nginx
RUN rm -f /etc/nginx/sites-enabled/default \
    && cp conf/nginx/webvirtcloud.conf /etc/nginx/conf.d/webvirtcloud.conf \
    && printf '\ndaemon off;\n' >> /etc/nginx/nginx.conf

# Persistent data dir (secret key, sqlite fallback db, logs)
RUN mkdir -p /var/lib/webvirtcloud /run/nginx \
    && chmod +x /docker-entrypoint.sh /usr/local/bin/wvc-config.py \
    && chown -R www-data:www-data \
        /srv/webvirtcloud \
        /var/lib/webvirtcloud \
        /run/nginx \
        /var/lib/nginx \
        /var/log/nginx

VOLUME /var/lib/webvirtcloud

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

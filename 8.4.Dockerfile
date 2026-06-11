FROM dunglas/frankenphp:php8.4-alpine

ARG S6_OVERLAY_VERSION=3.2.3.0
ARG TARGETPLATFORM

RUN install-php-extensions \
    curl \
    exif \
    gd \
    gmp \
    intl \
    mbstring \
    opcache \
    pcntl \
    pdo_pgsql \
    pgsql \
    redis \
    sodium \
    sockets \
    xdebug \
    zip

# Setup user permissions
RUN addgroup -S php \
    && adduser -S -G php php

# Install dependencies
RUN apk -U --no-cache add \
    ca-certificates \
    clamav \
    clamav-daemon \
    curl \
    fontconfig \
    freetype \
    git \
    libssl3 \
    libstdc++ \
    libx11 \
    libxrender \
    libxext \
    redis \
    supervisor \
    supercronic \
    ttf-dejavu \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    unzip \
    zip

# Install S6 overlay
RUN wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz; \
    wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz; \
    case "${TARGETPLATFORM}" in \
        "linux/amd64") \
            wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz; \
            tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
            ;; \
        "linux/arm64") \
            wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-aarch64.tar.xz; \
            tar -C / -Jxpf /tmp/s6-overlay-aarch64.tar.xz; \
            ;; \
        *) \
          echo "Cannot build, missing valid build platform." \
          exit 1; \
    esac; \
    rm -rf /tmp/*;

# Install composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Install wkhtmltopdf
COPY --from=surnet/alpine-wkhtmltopdf:3.23.2-0.12.6-full /bin/wkhtmltopdf /bin/wkhtmltopdf
COPY --from=surnet/alpine-wkhtmltopdf:3.23.2-0.12.6-full /bin/wkhtmltoimage /bin/wkhtmltoimage
COPY --from=surnet/alpine-wkhtmltopdf:3.23.2-0.12.6-full /bin/libwkhtmltox* /bin/

# Copy Redis Service and create data storage
COPY environment/etc/services.d/redis /etc/services.d/redis
RUN sed -i 's|  --protected-mode no|  --protected-mode no \\\n  --maxmemory 64mb \\\n  --maxmemory-policy allkeys-lru|' /etc/services.d/redis/run
RUN mkdir -p /redis-data \
    && chown -R redis:redis /redis-data \
    && chmod +x /etc/services.d/redis/run \
    && chmod +x /etc/services.d/redis/finish

# ClamAV user permissions
RUN mkdir /var/run/clamav && \
    touch /var/log/clamav/clamav.log && \
    chown -R php:php /var/run/clamav && \
    chown -R php:php /var/log/clamav && \
    chown php:php /etc/clamav /etc/clamav/clamd.conf /etc/clamav/freshclam.conf && \
    chmod 750 /var/run/clamav

# ClamAV Configuration update
COPY environment/transfer/clamav /transfer/clamav
RUN sed -i 's/^LocalSocketGroup .*$/LocalSocketGroup php/g' /etc/clamav/clamd.conf \
    && sed -i '/Foreground/s/^#//g' /etc/clamav/clamd.conf \
    && sed -i '/Foreground/s/^#//g' /etc/clamav/freshclam.conf \
    && sed -i 's/^User .*$/User php/g' /etc/clamav/clamd.conf

# Update ClamAV
RUN freshclam  # Update virus definitions
FROM php:7.4-fpm

# opencontainers annotations https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.authors="Alexis Saettler <alexis@saettler.org>" \
      org.opencontainers.image.title="OfficeLife." \
      org.opencontainers.image.description="Know how your employees feel." \
      org.opencontainers.image.url="https://officelife.io" \
      org.opencontainers.image.source="https://github.com/officelifehq/docker" \
      org.opencontainers.image.vendor="OfficeLife"

# entrypoint.sh dependencies
RUN set -ex; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash \
        busybox-static \
    ; \
    rm -rf /var/lib/apt/lists/*

# Install required PHP extensions
RUN set -ex; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libicu-dev \
        zlib1g-dev \
        libzip-dev \
        libpq-dev \
        libsqlite3-dev \
        libxml2-dev \
        libfreetype6-dev \
        libmemcached-dev \
    ; \
    \
    debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
    docker-php-ext-configure intl; \
    docker-php-ext-install -j$(nproc) \
        intl \
        zip \
        pdo_mysql \
        mysqli \
        pdo_pgsql \
        pdo_sqlite \
    ; \
    \
# pecl will claim success even if one install fails, so we need to perform each install separately
    pecl install APCu-5.1.19; \
    pecl install memcached-3.1.5; \
    pecl install redis-5.3.2; \
    \
    docker-php-ext-enable \
        apcu \
        memcached \
        redis \
    ; \
    \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
        ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { print $3 }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
        \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

# Set crontab for schedules
RUN set -ex; \
    \
    mkdir -p /var/spool/cron/crontabs; \
    rm -f /var/spool/cron/crontabs/root; \
    echo '*/5 * * * * php /var/www/html/artisan schedule:run -v' > /var/spool/cron/crontabs/www-data

# Opcache
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="0" \
    PHP_OPCACHE_MAX_ACCELERATED_FILES="20000" \
    PHP_OPCACHE_MEMORY_CONSUMPTION="192" \
    PHP_OPCACHE_MAX_WASTED_PERCENTAGE="10"
RUN set -ex; \
    \
    docker-php-ext-enable opcache; \
    { \
        echo '[opcache]'; \
        echo 'opcache.enable=1'; \
        echo 'opcache.revalidate_freq=0'; \
        echo 'opcache.validate_timestamps=${PHP_OPCACHE_VALIDATE_TIMESTAMPS}'; \
        echo 'opcache.max_accelerated_files=${PHP_OPCACHE_MAX_ACCELERATED_FILES}'; \
        echo 'opcache.memory_consumption=${PHP_OPCACHE_MEMORY_CONSUMPTION}'; \
        echo 'opcache.max_wasted_percentage=${PHP_OPCACHE_MAX_WASTED_PERCENTAGE}'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.fast_shutdown=1'; \
    } > $PHP_INI_DIR/conf.d/opcache-recommended.ini; \
    \
    echo 'apc.enable_cli=1' >> $PHP_INI_DIR/conf.d/docker-php-ext-apcu.ini; \
    \
    echo 'memory_limit=512M' > $PHP_INI_DIR/conf.d/memory-limit.ini



WORKDIR /var/www/html

# Define OfficeLife version
ENV OFFICELIFE_VERSION main
LABEL org.opencontainers.image.revision="" \
      org.opencontainers.image.version="main"
COPY officelife-${OFFICELIFE_VERSION}.tar.bz2 .

RUN set -ex; \
    fetchDeps=" \
        gnupg \
    "; \
    apt-get update; \
    apt-get install -y --no-install-recommends $fetchDeps; \
    \
    tar -xf officelife-${OFFICELIFE_VERSION}.tar.bz2 -C /var/www/html --strip-components=1; \
    \
    rm -r officelife-${OFFICELIFE_VERSION}.tar.bz2; \
    \
    cp /var/www/html/.env.example /var/www/html/.env; \
    chown -R www-data:www-data /var/www/html; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps; \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh \
    queue.sh \
    cron.sh \
    /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]

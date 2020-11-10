#!/bin/bash

set -Eeo pipefail

# wait for the database to start
waitfordb() {
    HOST=${DB_HOST:-mysql}
    PORT=${DB_PORT:-3306}
    echo "Connecting to ${HOST}:${PORT}"

    attempts=0
    max_attempts=30
    while [ $attempts -lt $max_attempts ]; do
        busybox nc -w 1 "${HOST}:${PORT}" && break
        echo "Waiting for ${HOST}:${PORT}..."
        sleep 1
        let "attempts=attempts+1"
    done

    if [ $attempts -eq $max_attempts ]; then
        echo "Unable to contact your database at ${HOST}:${PORT}"
        exit 1
    fi

    echo "Waiting for database to settle..."
    sleep 3
}

if expr "$1" : "apache" 1>/dev/null || [ "$1" = "php-fpm" ]; then

    HTMLDIR=/var/www/html
    ARTISAN="php ${HTMLDIR}/artisan"

    # Ensure storage directories are present
    STORAGE=${HTMLDIR}/storage
    mkdir -p ${STORAGE}/logs
    mkdir -p ${STORAGE}/app/public
    mkdir -p ${STORAGE}/framework/views
    mkdir -p ${STORAGE}/framework/cache
    mkdir -p ${STORAGE}/framework/sessions
    chown -R www-data:www-data ${STORAGE}
    chmod -R g+rw ${STORAGE}

    if [ "${DB_CONNECTION:-sqlite}" == "sqlite" ]; then
      touch "${DB_DATABASE:-database/database.sqlite}"
      chown www-data:www-data "${DB_DATABASE:-database/database.sqlite}"
    fi

    if [ -z "${APP_KEY:-}" ]; then
        ${ARTISAN} key:generate --no-interaction
    else
        echo "APP_KEY already set"
    fi

    if [ "${DB_CONNECTION:-sqlite}" != "sqlite" ]; then
      waitfordb
    fi
    ${ARTISAN} setup --force -vv

fi

exec "$@"

#!/bin/bash

set -Eeo pipefail

# wait for the database to start
waitfordb() {
    TERM=dumb php -- <<'EOPHP'
<?php
function env(string $name, ?string $default = null): ?string
{
    $val = getenv($name);
    return $val === false ? $default : $val;
}

$stderr = fopen('php://stderr', 'w');

if (! env('DATABASE_URL')) {
    $host = env('DB_HOST', '127.0.0.1');
    $port = (int) env('DB_PORT', '3306');
    $user = env('DB_USERNAME', 'homestead');
    $pass = env('DB_PASSWORD', 'secret');
    $database = env('DB_DATABASE', 'monica');
    $socket = env('DB_UNIX_SOCKET');
} else {
    $url = parse_url(env('DATABASE_URL'));
    $host = $url['host'];
    $port = array_key_exists('port', $url) ? (int) $url['port'] : 0;
    $user = $url['user'];
    $pass = $url['pass'];
    $database = ltrim($url['path'], '/');
    $socket = null;
    if ($url['query'] && strpos($url['query'], 'unix_socket=') !== false) {
        $socket = substr($url['query'], strlen('unix_socket='));
    }
}

$collation = ((bool) env('DB_USE_UTF8MB4', true)) ? ['utf8mb4','utf8mb4_unicode_ci'] : ['utf8','utf8_unicode_ci'];

$maxAttempts = 30;
do {
    $mysql = new mysqli($host, $user, $pass, '', $port, $socket);
    if ($mysql->connect_error) {
        fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
        --$maxAttempts;
        if ($maxAttempts <= 0) {
            fwrite($stderr, "\n" . 'Unable to contact your database');
            $mysql->close();
            exit(1);
        }
        fwrite($stderr, "\n" . 'Waiting for database to settle...');
        sleep(1);
    }
} while ($mysql->connect_error);
fwrite($stderr, "\n" . 'Database ready.');

if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($database) . '` CHARACTER SET ' . $collation[0] . ' COLLATE ' . $collation[1])) {
    fwrite($stderr, "\n" . 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
    $mysql->close();
    exit(1);
}

$mysql->close();
EOPHP
}

HTMLDIR=/var/www/html

# change uid/gid of www-data
if [ "$(id -u)" = 0 ]; then
    CURRENT_UID=$(id -u www-data)
    CURRENT_GID=$(id -g www-data)
    if [ -n "${UID+x}" ] && [ "$UID" -ne $CURRENT_UID ]; then
        echo "Change UID of www-data from $CURRENT_UID to $UID"
        usermod -u $UID www-data
        find $HTMLDIR -xdev -user $CURRENT_UID -exec chown -h www-data {} \;
    fi
    if [ -n "${GID+x}" ] && [ "$GID" -ne $CURRENT_GID ]; then
        echo "Change GID of www-data from $CURRENT_GID to $GID"
        groupmod -g $GID www-data
        find $HTMLDIR -xdev -group $CURRENT_GID -exec chgrp -h www-data {} \;
    fi
fi

if expr "$1" : "apache" 1>/dev/null || [ "$1" = "php-fpm" ]; then

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

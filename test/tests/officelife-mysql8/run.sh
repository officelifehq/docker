#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

mysqlImage='mysql:8'
# ensure the mysqlImage is ready and available
if ! docker image inspect "$mysqlImage" &> /dev/null; then
	docker pull "$mysqlImage" > /dev/null
fi

# Create an instance of the container-under-test
mysqlCid="$(docker run -d \
	-e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
	-e MYSQL_DATABASE=officelife \
	-e MYSQL_USER=officelife \
	-e MYSQL_PASSWORD=secret \
	"$mysqlImage")"
trap "docker rm -vf $mysqlCid > /dev/null" EXIT

cid="$(docker run -d \
	--link "$mysqlCid":mysql \
	-e DB_HOST=mysql \
	-e DB_PORT=3306 \
	-e DB_CONNECTION=mysql \
	-e DB_DATABASE=officelife \
	-e DB_USERNAME=officelife \
	-e DB_PASSWORD=secret \
	"$image")"
trap "docker rm -vf $cid $mysqlCid > /dev/null" EXIT

_artisan() {
	docker exec "$cid" php artisan "$@"
}

# Give some time to install
. "$dir/../../retry.sh" --tries 30 "_artisan migrate:status"

# Check if installation is complete
_artisan migrate:status > /dev/null 2>&1

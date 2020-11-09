#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

pgsqlImage='postgres:13.0'
# ensure the pgsqlImage is ready and available
if ! docker image inspect "$pgsqlImage" &> /dev/null; then
	docker pull "$pgsqlImage" > /dev/null
fi

# Create an instance of the container-under-test
pgsqlCid="$(docker run -d \
	-e POSTGRES_DB=officelife \
	-e POSTGRES_USER=officelife \
	-e POSTGRES_PASSWORD=secret \
	"$pgsqlImage")"
trap "docker rm -vf $pgsqlCid > /dev/null" EXIT

cid="$(docker run -d \
	--link "$pgsqlCid":pgsql \
	-e DB_HOST=pgsql \
	-e DB_PORT=5432 \
	-e DB_CONNECTION=pgsql \
	-e DB_DATABASE=officelife \
	-e DB_USERNAME=officelife \
	-e DB_PASSWORD=secret \
	"$image")"
trap "docker rm -vf $cid $pgsqlCid > /dev/null" EXIT

_artisan() {
	docker exec "$cid" php artisan "$@"
}

# Give some time to install
. "$dir/../../retry.sh" --tries 30 "_artisan migrate:status"

# Check if installation is complete
_artisan migrate:status > /dev/null 2>&1

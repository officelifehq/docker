#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

cid="$(docker run -d \
	-e DB_CONNECTION=sqlite \
	-e DB_DATABASE=/var/www/html/database/database.sqlite \
	"$image")"
trap "docker rm -vf $cid > /dev/null" EXIT

_artisan() {
	docker exec "$cid" php artisan "$@"
}

# Give some time to install
. "$dir/../../retry.sh" --tries 30 "_artisan migrate:status"

# Check if installation is complete
_artisan migrate:status > /dev/null 2>&1

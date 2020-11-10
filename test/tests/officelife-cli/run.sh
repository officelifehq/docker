#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

cid="$(docker run -d \
	"$image")"
trap "docker rm -vf $cid > /dev/null" EXIT

_artisan() {
	docker exec "$cid" php artisan "$@"
}

# Give some time to install
. "$dir/../../retry.sh" --tries 30 "_artisan migrate:status"

# Check if installation is complete
_artisan schedule:run | grep -iq 'No scheduled commands are ready to run.'

#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

mysqlImage='mysql:5.7'
# ensure the mysqlImage is ready and available
if ! docker image inspect "$mysqlImage" &> /dev/null; then
	docker pull "$mysqlImage" > /dev/null
fi

# Create an instance of the container-under-test
mysqlCid="$(docker run -d \
	-e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
	-e MYSQL_DATABASE=officelife \
	"$mysqlImage")"
trap "docker rm -vf $mysqlCid > /dev/null" EXIT

cid="$(docker run -d \
	--link "$mysqlCid":mysql \
	-e DB_HOST=mysql \
	-e DB_CONNECTION=mysql \
	"$image")"
trap "docker rm -vf $cid $mysqlCid > /dev/null" EXIT

_request() {
	local method="$1"
	shift

	local url="${1#/}"
	shift

	docker run --rm --link "$cid":apache "$image" \
		curl -fsL -X"$method" "$@" "http://apache/$url"
}

# Make sure that Apache is listening and ready
. "$dir/../../retry.sh" --tries 30 '_request GET / --output /dev/null'

# Check that we can request / and that it contains the pattern "Welcome" somewhere
_request GET '/' |tac|tac| grep -iq "Welcome"
_request GET '/signup' |tac|tac| grep -iq '&quot;url&quot;:&quot;\\/signup&quot;'

# (without "|tac|tac|" we get "broken pipe" since "grep" closes the pipe before "curl" is done reading it)

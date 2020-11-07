#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

# Build a client image with cgi-fcgi for testing
clientImage="librarytest/officelife-fpm-run:fcgi-client"
docker build -t "$clientImage" - > /dev/null <<'EOF'
FROM debian:stretch-slim

RUN set -x && apt-get update && apt-get install -y libfcgi0ldbl && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["cgi-fcgi"]
EOF

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

echo $cid

fcgi-request() {
	local method="$1"

	local url="$2"
	local requestUri="$3"
	local queryString=
	if [[ "$url" == *\?* ]]; then
		queryString="${url#*\?}"
		url="${url%%\?*}"
	fi

	docker run --rm -i --link "$cid":fpm \
		-e REQUEST_METHOD="$method" \
		-e SCRIPT_NAME="$url" \
		-e SCRIPT_FILENAME=/var/www/html/public/"${url#/}" \
		-e QUERY_STRING="$queryString" \
		-e REQUEST_URI="$requestUri" \
		"$clientImage" \
		-bind -connect fpm:9000
}

# Make sure that PHP-FPM is listening and ready
. "$dir/../../retry.sh" --tries 30 'fcgi-request GET index.php' > /dev/null 2>&1

# Check that we can request /register and that it contains the pattern "Welcome" somewhere
fcgi-request GET '/index.php' '' |tac|tac| grep -iq 'Welcome'
fcgi-request GET '/index.php' signup |tac|tac| grep -iq '&quot;url&quot;:&quot;\\/signup&quot;'

# (without "|tac|tac|" we get "broken pipe" since "grep" closes the pipe before "curl" is done reading it)
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

cid="$(docker run -d \
	-e DB_CONNECTION=sqlite \
	-e DB_DATABASE=/var/www/html/database/database.sqlite \
	"$image")"
trap "docker rm -vf $cid > /dev/null" EXIT

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
		-e HTTP_HOST="localhost" \
		-e SERVER_PORT="80" \
		"$clientImage" \
		-bind -connect fpm:9000
}

# Make sure that PHP-FPM is listening and ready
. "$dir/../../retry.sh" --tries 30 'fcgi-request GET index.php' > /dev/null 2>&1

# Check that we can request /register and that it contains the pattern "Welcome" somewhere
fcgi-request GET '/index.php' '/' |tac|tac| grep -iq 'Welcome'
fcgi-request GET '/index.php' '/signup' |tac|tac| grep -iq '&quot;url&quot;:&quot;\\/signup&quot;'

# (without "|tac|tac|" we get "broken pipe" since "grep" closes the pipe before "curl" is done reading it)

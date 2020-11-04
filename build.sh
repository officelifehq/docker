#!/bin/bash

set -Eeo pipefail

variants=${1-apache fpm fpm-alpine}

for variant in $variants; do
	pushd $variant
	docker pull php:7.4-$variant
	docker build --no-cache -t officelife:$variant .
	popd
done

docker images

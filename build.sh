#!/bin/bash

set -Eeo pipefail

build() {
	for variant in $variants; do
		pushd 0/$variant
		docker pull php:8.0-$variant
		docker build --no-cache -t officelife:$variant .
		popd
	done
}

build_main() {
	for variant in $variants; do
		pushd main/$variant
	    if [ ! -f ../../../officelife/officelife-main.tar.bz2 ]; then
		  pushd ../../../officelife
		  scripts/package.sh main
		  popd
		fi
		cp -f ../../../officelife/officelife-main.tar.bz2 .
		docker pull php:8.0-$variant
		docker build --no-cache -t officelife:$variant-main .
		popd
	done
}

versions=${1-0 main}
variants=${2-apache fpm fpm-alpine}

for version in $versions; do
  if [ "$version" == "main" ]; then
    build_main
  else
    build
  fi
done

docker images

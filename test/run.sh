#!/usr/bin/env bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

$dir/../official-images/test/run.sh -c $dir/config.sh "$@"

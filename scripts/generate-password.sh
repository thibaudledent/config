#!/usr/bin/env bash
set -eEuo pipefail

docker run --rm -it debian bash -c "</dev/urandom tr -dc 'A-Za-z0-9!#$%&'\''()*+,-./:;<=>?@[\]^_{}~' | head -c ${1:-128} ; echo"
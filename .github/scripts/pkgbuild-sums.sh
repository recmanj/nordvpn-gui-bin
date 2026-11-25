#!/usr/bin/env bash
# Prints the PKGBUILD checksums in the same format as `upstream.sh sums`
set -euo pipefail

# shellcheck disable=SC1091
source PKGBUILD
# shellcheck disable=SC2154
for a in "${arch[@]}"; do
  declare -n sums="sha256sums_$a"
  echo "$a ${sums[*]}"
  unset -n sums
done

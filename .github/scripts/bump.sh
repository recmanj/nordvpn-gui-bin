#!/usr/bin/env bash
# Sets PKGBUILD to VERSION with checksums from the signed repo metadata and
# regenerates .SRCINFO. Nothing from the release itself is downloaded or run,
# so the update workflow's publish job uses this to recreate both files.
#
#   bump.sh VERSION [SUMS]
#
# SUMS, in the format of `upstream.sh sums`, makes it fail if the signed
# metadata no longer lists those checksums. The update workflow passes the
# ones its check job saw, so the PR never gets checksums that were not
# validated.
set -euo pipefail

version=${1:?usage: bump.sh VERSION [SUMS]}
pinned=${2:-}
[[ $version =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "::error::Invalid version: $version" >&2; exit 1; }
scripts=$(dirname "${BASH_SOURCE[0]}")

sed -i -E "s/^pkgver=.*/pkgver=$version/; s/^pkgrel=.*/pkgrel=1/" PKGBUILD

# Checksums come from the signed repo metadata rather than from whatever
# the download returns
expected=$("$scripts/upstream.sh" sums "$version")
if [[ -n $pinned && $expected != "$pinned" ]]; then
  diff -u <(echo "$pinned") <(echo "$expected") || :
  echo "::error::Checksums for $version changed since the update check" >&2
  exit 1
fi
while read -r arch sums; do
  awk -v name="sha256sums_$arch" -v sums="$sums" '
    index($0, name "=(") == 1 {
      n = split(sums, s, " ")
      pad = sprintf("%*s", length(name) + 2, "")
      for (i = 1; i <= n; i++)
        printf "%s\x27%s\x27%s\n", (i == 1 ? name "=(" : pad), s[i], (i == n ? ")" : "")
      skip = ($0 !~ /\)$/)
      next
    }
    skip { if ($0 ~ /\)$/) skip = 0; next }
    { print }' PKGBUILD > PKGBUILD.new
  mv PKGBUILD.new PKGBUILD
done <<< "$expected"

actual=$("$scripts/pkgbuild-sums.sh")
if [[ $actual != "$expected" ]]; then
  diff -u <(echo "$expected") <(echo "$actual") || :
  echo '::error::Failed to update checksums in PKGBUILD'
  exit 1
fi

# makepkg refuses to run as root and needs a writable build directory
if (( EUID == 0 )); then
  id builder &>/dev/null || useradd -m builder
  chown builder: .
  # Root writing the output is intended
  # shellcheck disable=SC2024
  sudo -u builder makepkg --printsrcinfo > .SRCINFO
else
  makepkg --printsrcinfo > .SRCINFO
fi

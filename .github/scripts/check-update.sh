#!/usr/bin/env bash
set -euo pipefail

scripts=$(dirname "${BASH_SOURCE[0]}")

latest=$("$scripts/upstream.sh" latest)
current=$(sed -n "s/^\tpkgver = //p" .SRCINFO)
if (( $(vercmp "$latest" "$current") <= 0 )); then
  echo "Up to date: $current"
  exit 0
fi

branch="update/$latest"
# A PR in any state means this version was handled. A branch without a PR is
# left over from a failed run and gets overwritten.
if [[ -n $(gh pr list --head "$branch" --state all --json number --jq '.[].number') ]]; then
  echo "PR for $branch already exists, skipping"
  exit 0
fi

echo "Updating $current -> $latest"
sed -i -E "s/^pkgver=.*/pkgver=$latest/; s/^pkgrel=.*/pkgrel=1/" PKGBUILD

# Checksums come from the signed repo metadata rather than from whatever
# the download returns
expected=$("$scripts/upstream.sh" sums "$latest")
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

echo "version=$latest" >> "$GITHUB_OUTPUT"

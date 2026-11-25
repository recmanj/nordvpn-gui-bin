#!/usr/bin/env bash
# Writes the version and its checksums (`upstream.sh sums`) to $GITHUB_OUTPUT
# when the repo has a release newer than .SRCINFO that no PR has handled yet.
# Changes no files.
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
# left over from a failed run and gets overwritten. --head matches the branch
# name in any repo, so a fork PR could otherwise suppress the update; only
# count PRs from this repo into main.
if [[ -n $(gh pr list --head "$branch" --base main --state all \
  --json number,isCrossRepository \
  --jq '.[] | select(.isCrossRepository | not) | .number') ]]; then
  echo "PR for $branch already exists, skipping"
  exit 0
fi

echo "Updating $current -> $latest"
sums=$("$scripts/upstream.sh" sums "$latest")
{
  echo "version=$latest"
  echo 'sums<<EOF'
  echo "$sums"
  echo 'EOF'
} >> "$GITHUB_OUTPUT"

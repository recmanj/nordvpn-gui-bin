#!/usr/bin/env bash
set -euo pipefail

missing=$(ldd /usr/lib/nordvpn-gui/nordvpn-gui | grep 'not found' || :)
if [[ -n $missing ]]; then
  echo "$missing"
  echo '::error::Unresolved shared libraries'
  exit 1
fi

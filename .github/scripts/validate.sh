#!/usr/bin/env bash
# UPDATE_SRCINFO=1 regenerates .SRCINFO first.
set -euo pipefail

pacman -Syu --noconfirm --needed namcap shellcheck

# nordvpn comes from nordvpn-bin, which is not in the official repos.
# Install the rest of depends; the build itself needs none of them.
# shellcheck disable=SC1091,SC2154
mapfile -t deps < <(source PKGBUILD; printf '%s\n' "${depends[@]}" | grep -v '^nordvpn')
pacman -S --noconfirm --needed --asdeps "${deps[@]}"

id builder &>/dev/null || useradd -m builder
echo 'builder ALL=(root) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/builder
chown -R builder: .

sudo -u builder UPDATE_SRCINFO="${UPDATE_SRCINFO:-0}" bash -euo pipefail <<'EOF'
if [[ $UPDATE_SRCINFO == 1 ]]; then
  echo '::group::Update .SRCINFO'
  makepkg --printsrcinfo > .SRCINFO
  echo '::endgroup::'
fi

echo '::group::.SRCINFO is up to date'
diff -u .SRCINFO <(makepkg --printsrcinfo)
echo '::endgroup::'

echo '::group::shellcheck'
shellcheck --shell=bash --exclude=SC2034,SC2154,SC2164 PKGBUILD
shellcheck .github/scripts/*.sh
echo '::endgroup::'

echo '::group::Checksums match the signed repo metadata'
diff -u <(.github/scripts/upstream.sh sums "$(source PKGBUILD; echo "$pkgver")") \
  <(.github/scripts/pkgbuild-sums.sh)
echo '::endgroup::'

# --verifysource only checks CARCH
for arch in $(source PKGBUILD; echo "${arch[@]}"); do
  echo "::group::Checksums ($arch)"
  sed "s/^CARCH=.*/CARCH=\"$arch\"/" /etc/makepkg.conf > "/tmp/makepkg-$arch.conf"
  makepkg --config "/tmp/makepkg-$arch.conf" --verifysource --noconfirm
  echo '::endgroup::'
done

echo '::group::namcap PKGBUILD'
namcap PKGBUILD | tee /tmp/namcap.txt
echo '::endgroup::'

echo '::group::Build'
PKGEXT=.pkg.tar makepkg --nodeps --cleanbuild --noconfirm
echo '::endgroup::'

echo '::group::namcap package'
namcap ./*.pkg.tar | tee -a /tmp/namcap.txt
echo '::endgroup::'

if grep -q ' E: ' /tmp/namcap.txt; then
  echo '::error::namcap reported errors'
  exit 1
fi
EOF

echo '::group::Install and smoke test'
# -dd: nordvpn is not installable here, see above
pacman -U --noconfirm -dd ./*.pkg.tar
missing=$(ldd /usr/lib/nordvpn-gui/nordvpn-gui | grep 'not found' || :)
if [[ -n $missing ]]; then
  echo "$missing"
  echo '::error::Unresolved shared libraries'
  exit 1
fi
echo '::endgroup::'

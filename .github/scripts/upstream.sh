#!/usr/bin/env bash
# Reads NordVPN's apt repo. The debs are not signed themselves, so their
# checksums come from the Packages files, whose hashes are listed in the
# InRelease file, which is signed with the key in keys/pgp.
#
#   upstream.sh latest         newest version published for every package and arch
#   upstream.sh sums VERSION   "<arch> <sha256 per package>" per arch
set -euo pipefail

repo=https://repo.nordvpn.com/deb/nordvpn/debian
packages=(nordvpn-gui)
arches=(x86_64 aarch64)
declare -A debarch=([x86_64]=amd64 [aarch64]=arm64)
keys_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../keys/pgp" && pwd)

die() { echo "::error::$*" >&2; exit 1; }
fetch() { curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$2" "$1"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GNUPGHOME="$tmp/gnupg"
mkdir -m 0700 "$GNUPGHOME"

cat "$keys_dir"/*.asc | gpg --batch --dearmor > "$tmp/keyring.gpg"
fetch "$repo/dists/stable/InRelease" "$tmp/InRelease"
# --output keeps only the signed part
gpgv --keyring "$tmp/keyring.gpg" --output "$tmp/Release" "$tmp/InRelease" 2> "$tmp/gpgv.log" ||
  { cat "$tmp/gpgv.log" >&2; die 'InRelease signature verification failed'; }

for a in "${arches[@]}"; do
  da=${debarch[$a]}
  fetch "$repo/dists/stable/main/binary-$da/Packages" "$tmp/Packages-$da"
  expected=$(awk -v f="main/binary-$da/Packages" '
    /^[^ ]/ { in_sha = ($1 == "SHA256:") }
    in_sha && $3 == f { print $1 }' "$tmp/Release")
  actual=$(sha256sum < "$tmp/Packages-$da" | cut -d' ' -f1)
  [[ -n $expected && $expected == "$actual" ]] || die "Packages for $da does not match InRelease"
done

# Prints field $4 of every stanza in Packages file $1 with Package $2 and Version $3
# (any version when $3 is empty)
field() {
  awk -v p="$2" -v v="$3" -v f="$4" '
    BEGIN { RS = ""; FS = "\n" }
    {
      delete h
      for (i = 1; i <= NF; i++)
        if (match($i, /^[A-Za-z0-9-]+: /))
          h[substr($i, 1, RLENGTH - 2)] = substr($i, RLENGTH + 1)
      if (h["Package"] == p && (v == "" || h["Version"] == v)) print h[f]
    }' "$1"
}

case ${1:-} in
  latest)
    # A version counts once every package exists for every arch
    for a in "${arches[@]}"; do
      for p in "${packages[@]}"; do
        field "$tmp/Packages-${debarch[$a]}" "$p" '' Version | sort -u
      done
    done | grep -E '^[0-9]+(\.[0-9]+)*$' | sort | uniq -c |
      awk -v n=$(( ${#arches[@]} * ${#packages[@]} )) '$1 == n { print $2 }' |
      sort -V | tail -n1 | grep . || die 'No version found'
    ;;
  sums)
    version=${2:?usage: upstream.sh sums VERSION}
    for a in "${arches[@]}"; do
      da=${debarch[$a]}
      line=$a
      for p in "${packages[@]}"; do
        file=$(field "$tmp/Packages-$da" "$p" "$version" Filename)
        sum=$(field "$tmp/Packages-$da" "$p" "$version" SHA256)
        [[ $file == "pool/main/n/$p/${p}_${version}_$da.deb" ]] ||
          die "Unexpected Filename for $p $version $da: $file"
        [[ $sum =~ ^[0-9a-f]{64}$ ]] || die "Unexpected SHA256 for $p $version $da: $sum"
        line+=" $sum"
      done
      echo "$line"
    done
    ;;
  *)
    die 'usage: upstream.sh latest | sums VERSION'
    ;;
esac

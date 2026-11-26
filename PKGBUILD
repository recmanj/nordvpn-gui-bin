# Maintainer: recmanj <recmanj at gmail dot com>

pkgname=nordvpn-gui-bin
_pkgname=nordvpn-gui
pkgver=6.1.1
pkgrel=1
pkgdesc='NordVPN graphical interface (binary release)'
arch=(x86_64 aarch64)
url='https://nordvpn.com/download/linux/'
# Sources are GPL-3.0-only; upstream labels the deb "License: Proprietary"
license=('GPL-3.0-only' 'LicenseRef-NordVPN')
# Upstream pins the daemon to the same version. >= lets nordvpn-bin be
# upgraded first instead of the two having to be installed together.
depends=("nordvpn>=$pkgver" at-spi2-core cairo fontconfig gdk-pixbuf2 glib2 glibc gtk3
	harfbuzz hicolor-icon-theme libepoxy libgcc libstdc++ libx11 pango)
provides=("$_pkgname=$pkgver")
conflicts=("$_pkgname")
options=(!strip !debug)
_pool="https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/$_pkgname"
source_x86_64=("$_pool/${_pkgname}_${pkgver}_amd64.deb")
source_aarch64=("$_pool/${_pkgname}_${pkgver}_arm64.deb")
# The deb is not signed; these come from the signed repo metadata,
# see .github/scripts/upstream.sh
sha256sums_x86_64=('f64ffe37ce483c0f717b8b565825cce2d7e350885c5b8470a0641ae93d25cd01')
sha256sums_aarch64=('a26f482ff4e0b4b2f71cc7747689ec91d389efc9ae8a82f039ae6b0163f9c101')

prepare() {
	rm -rf data
	mkdir data
	# makepkg extracts the deb; data.tar.* is its payload
	bsdtar -xf "$srcdir"/data.tar.* -C data
}

package() {
	local _src="$srcdir/data"

	install -dm0755 "$pkgdir/usr/lib" "$pkgdir/usr/bin"
	cp -a "$_src/opt/$_pkgname" "$pkgdir/usr/lib/$_pkgname"
	# The deb's postinst creates this symlink
	ln -s "/usr/lib/$_pkgname/$_pkgname" "$pkgdir/usr/bin/$_pkgname"

	install -Dm0644 -t "$pkgdir/usr/share/applications/" \
		"$_src/usr/share/applications/$_pkgname.desktop"
	install -Dm0644 -t "$pkgdir/usr/share/icons/hicolor/scalable/apps/" \
		"$_src/usr/share/icons/hicolor/scalable/apps/$_pkgname.svg"

	install -Dm0644 /dev/stdin "$pkgdir/usr/share/licenses/$pkgname/LICENSE.NordVPN" <<-'LICENSE'
	The NordVPN for Linux sources are published under GPL-3.0-only at
	https://github.com/NordSecurity/nordvpn-linux.

	The binaries in this package are taken unmodified from NordVPN's Debian
	repository, which labels them "License: Proprietary". They are subject to
	NordVPN's Terms of Service: https://my.nordaccount.com/legal/terms-of-service/
	LICENSE
}

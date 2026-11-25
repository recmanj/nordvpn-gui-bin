# nordvpn-gui-bin

Arch Linux package for the NordVPN GUI, repackaged from NordVPN's official
Debian repository. It needs the daemon from
[nordvpn-bin](https://github.com/recmanj/nordvpn-bin), so install that first.

## Installation

```sh
git clone https://github.com/recmanj/nordvpn-gui-bin.git
cd nordvpn-gui-bin
makepkg -si
```

## Updating

```sh
git pull
makepkg -si
```

Update nordvpn-bin first. The GUI requires a daemon of the same version or
newer.

A daily workflow opens a pull request when NordVPN publishes a new version.

## Checksums

NordVPN does not sign the .deb files, only the repository metadata. The
checksums in the PKGBUILD are taken from the repository's `Packages` index,
which is checked against the `InRelease` file signed with the key in
[`keys/pgp`](keys/pgp) (`BC5480EFEC5C081CE5BCFBE26B219E535C964CA1`). CI repeats
this check on every change.

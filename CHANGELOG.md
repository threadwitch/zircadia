# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Switch NetworkManager WiFi backend to iwd for better reliability on Intel AX2xx/AX3xx and mixed WPA2/WPA3 networks
- `zjust update-all` recipe to upgrade the base image, Flatpaks, and Homebrew together

### Fixed
- Restore jj 0.44.0 installation from its checksummed upstream release instead of an unavailable COPR RPM
- Detect pinned Nushell and jj versions with Renovate
- Move the iwd backend drop-in from the invalid `/etc/NetworkManager/NetworkManager.conf.d/` to `/etc/NetworkManager/conf.d/`, the directory NetworkManager actually reads; the previous path was silently ignored so NM stayed on wpa_supplicant and WiFi kept failing the handshake
- Rename duplicate `zjust update` recipe to `update-all` so just no longer fails to load recipes
- faugus-launcher installed twice; flatpak preinstall file silently ignored (#4)
- Fix iso.toml kickstart: rebases installs to upstream zirconium instead of zircadia (#1)

### Changed
- Disable the 1Password build recipe and its dedicated integrations; retain generic YubiKey and PC/SC support
- Remove ublue template residue (README, JustfileU.bak, stale ISO tomls, artifacthub placeholder, dependabot) (#6)
- build.yml cleanup: dead references and amd64-only manifest machinery (#5)
- Containerfile/build-script dead code and cleanup (#3)
- Pin BASE_IMAGE by digest and replace daily cron with push/dispatch builds (#2)

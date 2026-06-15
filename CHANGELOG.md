# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

### Fixed
- zjust update recipe missing — no way to trigger a system update via zjust (#7)
- faugus-launcher installed twice; flatpak preinstall file silently ignored (#4)
- Fix iso.toml kickstart: rebases installs to upstream zirconium instead of zircadia (#1)

### Changed
- Remove ublue template residue (README, JustfileU.bak, stale ISO tomls, artifacthub placeholder, dependabot) (#6)
- build.yml cleanup: dead references and amd64-only manifest machinery (#5)
- Containerfile/build-script dead code and cleanup (#3)
- Pin BASE_IMAGE by digest and replace daily cron with push/dispatch builds (#2)

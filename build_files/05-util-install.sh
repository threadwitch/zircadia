#!/usr/bin/env bash

set -xeou pipefail

dnf -y --enablerepo=terra install \
	yazi \
	7zip \
	poppler \
	fd-find \
	ripgrep \
	fzf \
	zoxide \
	ImageMagick \
	helium-browser-bin

# Apparently this should help with printing issues?
dnf -y install system-config-printer system-config-printer-applet

# Use iwd as the NetworkManager WiFi backend. It handles Intel AX2xx/AX3xx
# and mixed WPA2/WPA3 networks more reliably than wpa_supplicant on some
# consumer routers (e.g., ThinkPad X1 Carbon Gen 11).
dnf -y install iwd

# YubiKey Stuff
dnf -y install \
	pam-u2f \
	pam_yubico \
	pamu2fcfg \
	yubikey-manager

# Smartcard / PC-SC: age-plugin-yubikey and GnuPG's scdaemon need direct PC/SC
# access to the YubiKey CCID interface. opensc's PKCS#11/CCID integration grabs
# that interface and prevents pcscd from serving the card
# (https://bugzilla.redhat.com/show_bug.cgi?id=1893131). Remove opensc and enable
# the pcscd activation socket so PC/SC works out of the box. pcscd.service is
# socket-activated (no WantedBy of its own), so enable pcscd.socket, not the
# service.
if rpm -q opensc >/dev/null 2>&1; then
	dnf -y remove opensc
fi
systemctl enable pcscd.socket

# Bootstrap tools available from Fedora. Keep age from Fedora.
dnf -y install age

# Nushell from Gemfury: Fedora/Terra lag upstream (Fedora ships 0.99.x; upstream
# is 0.114.x). Gemfury tracks upstream. Pin to the latest version for a
# deliberate, reproducible install rather than accepting a moving target.
# NOTE: Gemfury RPMs are unsigned, so gpgcheck=0 is required (see repo file).
# renovate: datasource=github-releases depName=nushell/nushell
cat > /etc/yum.repos.d/fury-nushell.repo <<'EOF'
[gemfury-nushell]
name=Gemfury Nushell Repo
baseurl=https://yum.fury.io/nushell/
enabled=1
gpgcheck=0
gpgkey=https://yum.fury.io/nushell/gpg.key
EOF
# The Gemfury RPM %post runs `mkdir -p "$HOME/.config"`. On this bootc image
# $HOME=/root is a symlink to /var/roothome, which already exists, so mkdir
# errors and dnf5 escalates the non-critical scriptlet failure into a
# transaction failure (same class as 1Password, commit 7fcfa77). The scriptlet
# only runs post-install.nu to register plugins into the user's config dir,
# which is live-state that belongs to the running system, not the image.
# Install with scriptlets disabled; plugins register on first login.
dnf -y install --setopt=tsflags=noscripts nushell-0.114.1

# age-plugin-yubikey is not packaged for Fedora 44. Build the pinned crate
# against Fedora's system pcsc-lite, then remove the toolchain; unlike the
# Homebrew bottle, this resolves /run/pcscd/pcscd.comm without an environment
# override.
dnf -y install cargo pcsc-lite-devel
# renovate: datasource=crate depName=age-plugin-yubikey
age_plugin_yubikey_version="0.5.1"
export CARGO_HOME=/tmp/cargo-home
cargo install \
	--locked \
	--root /tmp/age-plugin-yubikey \
	--version "${age_plugin_yubikey_version}" \
	age-plugin-yubikey
install -m 0755 \
	/tmp/age-plugin-yubikey/bin/age-plugin-yubikey \
	/usr/bin/age-plugin-yubikey
dnf -y remove cargo pcsc-lite-devel
rm -rf /tmp/age-plugin-yubikey "${CARGO_HOME}"

# age-plugin-tpm is not packaged for Fedora 44. Its upstream release is a
# statically linked binary, so install the pinned, checksummed release artifact
# without adding a runtime dependency or leaving a Go toolchain in the image.
# renovate: datasource=github-releases depName=Foxboron/age-plugin-tpm
age_plugin_tpm_version="1.0.1"
age_plugin_tpm_url="https://github.com/Foxboron/age-plugin-tpm/releases/download/v${age_plugin_tpm_version}/age-plugin-tpm-v${age_plugin_tpm_version}-linux-amd64.tar.gz"
age_plugin_tpm_sha256="ba5930cef12998e1bf5e979bcbb45e4e4cefdac773144b57f7e9e391c8c7e3fe"
curl -fsSL "${age_plugin_tpm_url}" -o /tmp/age-plugin-tpm.tar.gz
printf '%s  %s\n' "${age_plugin_tpm_sha256}" /tmp/age-plugin-tpm.tar.gz | sha256sum --check --strict
tar -xzf /tmp/age-plugin-tpm.tar.gz -C /tmp
install -m 0755 /tmp/age-plugin-tpm/age-plugin-tpm /usr/bin/age-plugin-tpm
rm -rf /tmp/age-plugin-tpm /tmp/age-plugin-tpm.tar.gz

# sops and jj are not packaged for Fedora 44. Install pinned upstream release
# artifacts only after checking their published SHA-256 digests.
# renovate: datasource=github-releases depName=getsops/sops
sops_version="3.13.3"
sops_url="https://github.com/getsops/sops/releases/download/v${sops_version}/sops-${sops_version}-1.x86_64.rpm"
sops_sha256="f362eabc5b17b84894952fc57737eccf26ef8a4321453c165f4b1205b5544123"
curl -fsSL "${sops_url}" -o /tmp/sops.rpm
printf '%s  %s\n' "${sops_sha256}" /tmp/sops.rpm | sha256sum --check --strict
dnf -y install /tmp/sops.rpm
rm -f /tmp/sops.rpm

# jj from the jj-vcs COPR (GPG-signed) tracks upstream (Fedora/Terra lag).
# Pin to the latest upstream version for a deliberate, reproducible install.
# Disable weak deps to avoid pulling editor/pager extras (bat, 7zip, unzip).
# renovate: datasource=github-releases depName=jj-vcs/jj
dnf -y copr enable aldantanneo/jj-vcs
dnf -y --setopt=install_weak_deps=False install jj-cli-0.44.0

# Fonts good.
dnf -y install \
	google-noto-fonts-all \
	google-noto-emoji-fonts \
	artwiz-aleczapka-fonts \
	atkinson-hyperlegible-next-fonts \
	atkinson-hyperlegible-mono-fonts \
	catharsis-cormorant-fonts-all \
	fontawesome-fonts-all \
	google-roboto-fonts \
	google-roboto-condensed-fonts \
	google-roboto-mono-fonts \
	google-roboto-slab-fonts \
	vernnobile-oswald-fonts

# Moar fonts
dnf -y --enablerepo=terra install \
	0xproto-nerd-fonts \
	ia-writer-nerd-fonts \
	inconsolata-nerd-fonts \
	iosevka-nerd-fonts \
	spacemono-nerd-fonts \
	opendyslexic-nerd-fonts

# I don't want this
dnf -y remove \
	valent \
	firefox \
	firefox-langpacks \
	fedora-chromium-config

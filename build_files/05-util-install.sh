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

# Bootstrap tools available from Fedora. Keep age and Nushell as RPMs so they
# receive normal image rebuild updates.
dnf -y install \
	age \
	nushell

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

# renovate: datasource=github-releases depName=jj-vcs/jj
jj_version="0.43.0"
jj_url="https://github.com/jj-vcs/jj/releases/download/v${jj_version}/jj-v${jj_version}-x86_64-unknown-linux-musl.tar.gz"
jj_sha256="59e5588583ac82b623239929368c65b90735931c0f26b5a16c1f04d5bb97643d"
curl -fsSL "${jj_url}" -o /tmp/jj.tar.gz
printf '%s  %s\n' "${jj_sha256}" /tmp/jj.tar.gz | sha256sum --check --strict
tar -xzf /tmp/jj.tar.gz -C /tmp
install -m 0755 /tmp/jj /usr/bin/jj
rm -f /tmp/jj /tmp/jj.tar.gz

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

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

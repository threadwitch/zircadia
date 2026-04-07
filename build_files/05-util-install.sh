#!/usr/bin/env bash

set -xeou pipefail

dnf -y --enablerepo=terra install \
	helium-browser-bin \
	vesktop

dnf -y --enablerepo="*mullvad*" install mullvad-vpn

# Apparently this should help with printing issues?
dnf -y install system-config-printer system-config-printer-applet

# Fonts good.
dnf -y install \
	google-noto-fonts-all \
	google-noto-emoji-fonts \
	artwiz-aleczapka-fonts \
	atkinson-hyperlegible-next-fonts \
	atkinson-hyperlegible-mono-fonts \
	catharsis-cormon-fonts-all \
	fontawesome-fonts-all \
	google-roboto-fonts \
	google-roboto-condensed-fonts \
	google-roboto-mono-fonts \
	google-roboto-slab-fonts \
	vernnobile-oswald-fonts

dnf -y --enablerepo=terra install \
	0xproto-nerd-fonts \
	ia-writer-nerd-fonts \
	inconsolata-nerd-fonts \
	iosevka-nerd-fonts \
	space-mono-nerd-fonts \
	opendyslexic-nerd-fonts

# I don't want this
dnf -y remove valent

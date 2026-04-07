#!/usr/bin/env bash

set -xeou pipefail

dnf -y --enablerepo=terra install \
	helium-browser-bin \
	vesktop

dnf -y --enablerepo="*mullvad*" install mullvad-vpn

# Apparently this should help with printing issues?
dnf -y install system-config-printer system-config-printer-applet

# I don't want this
dnf -y remove valent

#!/usr/bin/env bash

set -xeou pipefail

# Installing MEGAsync at the base level just because I don't want to deal with distroboxes and I'm setting this up.
# This doesn't work, it just segfaults on launch. wtf?
# dnf -y --enablerepo=rpmfusion-nonfree --enablerepo=rpmfusion-free install --allowerasing megasync

dnf -y install https://mega.nz/linux/repo/Fedora_43/x86_64/megasync-Fedora_43.x86_64.rpm

dnf -y --enablerepo=terra install \
	helium-browser-bin \
	vesktop

dnf -y --enablerepo="*mullvad*" install mullvad-vpn

# Apparently this should help with printing issues?
dnf -y install system-config-printer system-config-printer-applet

# I don't want this
dnf -y remove valent

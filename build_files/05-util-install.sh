#!/usr/bin/env bash

set -xeou pipefail

# Installing MEGAsync at the base level just because I don't want to deal with distroboxes and I'm setting this up.
# This doesn't work, it just segfaults on launch. wtf?
# dnf -y --enablerepo=rpmfusion-nonfree --enablerepo=rpmfusion-free install --allowerasing megasync

dnf -y --enablerepo=terra install \
	helium-browser-bin \
	discord \
	vencord-installer

dnf -y --enablerepo="*mullvad*" install mullvad-vpn

# Apparently this should help with printing issues?
dnf -y install system-config-printer system-config-printer-applet

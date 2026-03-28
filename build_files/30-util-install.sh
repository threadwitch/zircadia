#!/bin/bash

set -xeou pipefail

# Installing MEGAsync at the base level just because I don't want to deal with distroboxes and I'm setting this up.
dnf5 --enablerepo=rpmfusion-nonfree-rawhide -y install megasync

# Apparently this should help with printing issues?
dnf5 -y install system-config-printer-applet

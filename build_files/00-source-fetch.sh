#!/usr/bin/env bash

set -xeuo pipefail

dnf config-manager setopt keepcache=1
dnf config-manager setopt fastestmirror=True
trap 'dnf config-manager setopt keepcache=0' EXIT

dnf -y --enablerepo=terra --enablerepo=terra-extras install terra-release-mesa
dnf -y config-manager setopt terra-mesa.enabled=0

dnf -y install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf -y config-manager setopt "*rpmfusion*".enabled=0

dnf -y copr enable lizardbyte/beta
dnf -y copr disable lizardbyte/beta
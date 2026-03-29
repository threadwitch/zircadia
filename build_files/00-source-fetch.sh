#!/usr/bin/env bash

set -xeuo pipefail

dnf install -y dnf5-plugins

dnf config-manager setopt keepcache=1
dnf config-manager setopt fastestmirror=True
trap 'dnf config-manager setopt keepcache=0' EXIT

for copr in \
    ublue-os/bazzite \
    ublue-os/bazzite-multilib \
    ublue-os/staging \
    ublue-os/packages \
    ublue-os/obs-vkcapture \
    ycollet/audinux \
    ublue-os/hhd \
    lizardbyte/beta; \
do \
    echo "Enabling copr: $copr"; \
    dnf -y copr enable $copr; \
    dnf -y config-manager setopt copr:copr.fedorainfracloud.org:${copr////:}.priority=98 ;\
done && unset -v copr

dnf -y config-manager addrepo --overwrite --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo

dnf -y --enablerepo=terra --enablerepo=terra-extras install terra-release-mesa
dnf -y config-manager setopt terra-mesa.enabled=0

dnf5 -y install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
# sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo

dnf -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-steam.repo
dnf -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-rar.repo

dnf -y config-manager setopt "*bazzite*".priority=1
dnf -y config-manager setopt "*terra*".priority=3 "*terra*".exclude="nerd-fonts topgradegit  steam python3-protobuf zlib-devel"
eval "$(/ctx/dnf5-setopt setopt '*negativo17*' priority=4 exclude='mesa-* *xone*')"
dnf5 -y config-manager setopt "*rpmfusion*".priority=5 "*rpmfusion*".exclude="mesa-*"
dnf5 -y config-manager setopt "*fedora*".exclude="mesa-* kernel-core-* kernel-modules-* kernel-uki-virt-*"
dnf5 -y config-manager setopt "*staging*".exclude="scx-tools scx-scheds kf6-* mesa* mutter*"

dnf -y copr disable lizardbyte/beta
#!/usr/bin/env bash

set -xeuo pipefail

dnf config-manager setopt keepcache=1
dnf config-manager setopt fastestmirror=True
trap 'dnf config-manager setopt keepcache=0' EXIT

# dnf -y copr enable bieszczaders/kernel-cachyos
# dnf -y copr disable bieszczaders/kernel-cachyos

# dnf -y copr enable bieszczaders/kernel-cachyos-addons
# dnf -y copr disable bieszczaders/kernel-cachyos-addons

# dnf -y --enablerepo copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos install \
#     kernel-cachyos \
#     kernel-cachyos-devel

# dnf -y --enablerepo copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-addons swap \
#     zram-generator-defaults \
#     cachyos-settings

dnf -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo
dnf -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-steam.repo
dnf -y config-manager setopt fedora-multimedia.enabled=0
dnf -y config-manager setopt fedora-steam.enabled=0

dnf -y config-manager addrepo --from-repofile=https://repository.mullvad.net/rpm/stable/mullvad.repo
dnf -y config-manager setopt "*mullvad*".enabled=0

dnf -y --enablerepo=terra --enablerepo=terra-extras install terra-release-mesa
dnf -y config-manager setopt terra-mesa.enabled=0

dnf -y install \
	https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
	https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf -y config-manager setopt "*rpmfusion*".enabled=0

dnf -y copr enable lizardbyte/beta
dnf -y copr disable lizardbyte/beta

#!/usr/bin/env bash

set -xeuo pipefail

dnf -y config-manager setopt keepcache=1
dnf -y config-manager setopt fastestmirror=True
trap 'dnf -y config-manager setopt keepcache=0' EXIT

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

dnf -y --enablerepo=terra --enablerepo=terra-extras install \
    terra-release-mesa \
    terra-release-nvidia
dnf -y config-manager setopt terra-mesa.enabled=0
dnf -y config-manager setopt terra-nvidia.enabled=0

dnf -y copr enable lizardbyte/beta
dnf -y copr disable lizardbyte/beta

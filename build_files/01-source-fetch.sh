#!/usr/bin/env bash

set -xeuo pipefail

# keepcache=1 lets the --mount=type=cache,dst=/var/cache/libdnf5 cache persist
# across all build steps. It is intentionally left enabled for the rest of the
# build; the cache mount is not part of the shipped image.
dnf -y config-manager setopt keepcache=1
dnf -y config-manager setopt fastestmirror=True

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
    terra-release-mesa
dnf -y config-manager setopt terra-mesa.enabled=0

dnf -y copr enable lizardbyte/beta
dnf -y copr disable lizardbyte/beta

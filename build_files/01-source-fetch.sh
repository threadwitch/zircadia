#!/usr/bin/env bash

set -xeuo pipefail

# keepcache=1 lets the --mount=type=cache,dst=/var/cache/libdnf5 cache persist
# across all build steps. It is intentionally left enabled for the rest of the
# build; the cache mount is not part of the shipped image.
dnf -y config-manager setopt keepcache=1

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

# A base may ship only Fedora repos, so the Terra repos we --enablerepo below
# can be undefined rather than merely disabled, causing dnf5 to hard-error
# with "No matching repositories". This bootstrap only runs where Terra is
# genuinely missing. Once terra-release* is installed it lays down the Terra
# repo files, which 99-final-hooks.sh disables in the shipped image.
repo_list="$(dnf -q repolist --all)"
if ! grep -qE '^terra[[:space:]]' <<<"${repo_list}" ||
    ! grep -qE '^terra-extras[[:space:]]' <<<"${repo_list}"; then
    dnf -y config-manager addrepo \
        --from-repofile=https://raw.githubusercontent.com/terrapkg/subatomic-repos/main/terra.repo
    dnf -y --enablerepo=terra install terra-release terra-release-extras
fi

dnf -y --enablerepo=terra --enablerepo=terra-extras install \
	terra-release-mesa \
	terra-release-multimedia
dnf -y config-manager setopt terra-mesa.enabled=0
dnf -y config-manager setopt terra-multimedia.enabled=0
dnf -y config-manager setopt terra.enabled=0
dnf -y config-manager setopt terra-extras.enabled=0

dnf -y copr enable lizardbyte/beta
dnf -y copr disable lizardbyte/beta

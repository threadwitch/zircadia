#!/usr/bin/env bash

set -xeuo pipefail

trap 'dnf config-manager setopt keepcache=0' EXIT

dnf -y config-manager setopt multilib_policy=all
dnf -y swap --from-repo=terra-mesa mesa-filesystem mesa-filesystem
dnf -y swap --from-repo=terra-mesa mesa-vulkan-drivers mesa-vulkan-drivers
dnf -y config-manager setopt multilib_policy=best

dnf versionlock add \
	mesa-dri-drivers \
	mesa-filesystem \
	mesa-libEGL \
	mesa-libGL \
	mesa-libgbm \
	mesa-vulkan-drivers

dnf5 -y install --enable-repo="*rpmfusion*" libaacs

dnf -y --enablerepo=terra --enablerepo=terra-extras install \
	ffmpeg \
	libfreeaptx

#!/usr/bin/env bash

set -xeuo pipefail

trap 'dnf config-manager setopt keepcache=0' EXIT

dnf -y swap --from-repo=fedora-multimedia mesa-filesystem mesa-filesystem
dnf -y swap --from-repo=fedora-multimedia mesa-libEGL mesa-libEGL
dnf -y swap --from-repo=fedora-multimedia mesa-libGL mesa-libGL
dnf -y swap --from-repo=fedora-multimedia mesa-libgbm mesa-libgbm
dnf -y swap --from-repo=fedora-multimedia mesa-dri-drivers mesa-dri-drivers
dnf -y swap --from-repo=fedora-multimedia libva libva
dnf -y swap --from-repo=fedora-multimedia libva-intel-media-driver libva-intel-media-driver
dnf -y config-manager setopt multilib_policy=all
dnf -y swap --from-repo=fedora-multimedia mesa-vulkan-drivers mesa-vulkan-drivers
dnf -y config-manager setopt multilib_policy=best

dnf -y swap --from-repo=fedora-multimedia ffmpeg ffmpeg-free
dnf -y swap --from-repo=fedora-multimedia libavcodec libavcodec-free
dnf -y swap --from-repo=fedora-multimedia libavdevice libavdevice-free
dnf -y swap --from-repo=fedora-multimedia libavfilter libavfilter-free
dnf -y swap --from-repo=fedora-multimedia libavformat libavformat-free
dnf -y swap --from-repo=fedora-multimedia libavutil libavutil-free
dnf -y swap --from-repo=fedora-multimedia libpostproc libpostproc-free
dnf -y swap --from-repo=fedora-multimedia libswresample libswrresample-free
dnf -y swap --from-repo=fedora-multimedia libswscale libswscale-free

dnf versionlock add \
	mesa-dri-drivers \
	mesa-filesystem \
	mesa-libEGL \
	mesa-libGL \
	mesa-libgbm \
	mesa-vulkan-drivers

dnf5 -y install --enable-repo="*rpmfusion*" libaacs

dnf -y --enablerepo=terra --enablerepo=terra-extras install libfreeaptx

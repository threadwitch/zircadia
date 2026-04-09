#!/usr/bin/env bash

set -xeuo pipefail

trap 'dnf config-manager setopt keepcache=0' EXIT

dnf -y swap --from-repo=fedora-multimedia mesa-filesystem mesa-filesystem
dnf -y swap --from-repo=fedora-multimedia libva libva
dnf -y swap --from-repo=fedora-multimedia libva-intel-media-driver libva-intel-media-driver
dnf -y install --from-repo=fedora-multimedia mesa-vulkan-drivers.i686 libfreeaptx libfdk-aac libpostproc

dnf -y swap --from-repo=fedora-multimedia ffmpeg-free ffmpeg
dnf -y swap --from-repo=fedora-multimedia libavcodec-free libavcodec
dnf -y swap --from-repo=fedora-multimedia libavdevice-free libavdevice
dnf -y swap --from-repo=fedora-multimedia libavfilter-free libavfilter
dnf -y swap --from-repo=fedora-multimedia libavformat-free libavformat
dnf -y swap --from-repo=fedora-multimedia libavutil-free libavutil
dnf -y swap --from-repo=fedora-multimedia libpostproc-free libpostproc
dnf -y swap --from-repo=fedora-multimedia libswrresample-free libswresample
dnf -y swap --from-repo=fedora-multimedia libswscale-free libswscale

dnf versionlock add \
	mesa-dri-drivers \
	mesa-filesystem \
	mesa-libEGL \
	mesa-libGL \
	mesa-libgbm \
	mesa-vulkan-drivers \
	ffmpeg \
	libavcodec \
	libavdevice \
	libavfilter \
	libavformat \
	libavutil \
	libpostproc \
	libswresample \
	libswscale \
	libfreeaptx \
	libfdk-aac

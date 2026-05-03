#!/usr/bin/env bash

set -xeuo pipefail

trap 'dnf config-manager setopt keepcache=0' EXIT

dnf -y swap --from-repo=terra-mesa mesa-filesystem mesa-filesystem

dnf -y --enable-repo=terra-mesa install \
	mesa-libOpenCL \
	intel-opencl \
	clinfo

dnf versionlock add \
	mesa-dri-drivers \
	mesa-filesystem \
	mesa-libEGL \
	mesa-libGL \
	mesa-libgbm \
	mesa-vulkan-drivers 

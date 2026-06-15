#!/usr/bin/env bash

set -xeuo pipefail

dnf -y swap --from-repo=terra-mesa mesa-filesystem mesa-filesystem

dnf -y --enablerepo=terra-mesa install \
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

#!/usr/bin/env bash

set -xeuo pipefail

trap 'dnf config-manager setopt keepcache=0' EXIT

dnf5 -y remove \
    pipewire-config-raop \
    mesa-va-drivers

declare -A toswap=( \
    ["copr:copr.fedorainfracloud.org:ublue-os:bazzite"]="wireplumber" \
    ["copr:copr.fedorainfracloud.org:ublue-os:bazzite-multilib"]="pipewire bluez xorg-x11-server-Xwayland NetworkManager" \
    ["terra-mesa"]="mesa-filesystem" \
    ["copr:copr.fedorainfracloud.org:ublue-os:staging"]="fwupd" \
)
for repo in "${!toswap[@]}"; do \
    for package in ${toswap[$repo]}; do dnf -y --enablerepo=$repo swap $package $package; done; \
done && unset -v toswap repo package

dnf versionlock add \
    pipewire \
    pipewire-alsa \
    pipewire-gstreamer \
    pipewire-jack-audio-connection-kit \
    pipewire-jack-audio-connection-kit-libs \
    pipewire-libs \
    pipewire-plugin-libcamera \
    pipewire-pulseaudio \
    pipewire-utils \
    wireplumber \
    wireplumber-libs \
    bluez \
    bluez-cups \
    bluez-libs \
    bluez-obexd \
    xorg-x11-server-Xwayland \
    mesa-dri-drivers \
    mesa-filesystem \
    mesa-libEGL \
    mesa-libGL \
    mesa-libgbm \
    mesa-vulkan-drivers \
    fwupd \
    fwupd-plugin-flashrom \
    fwupd-plugin-modem-manager \
    fwupd-plugin-uefi-capsule-data \
    NetworkManager \
    NetworkManager-wifi \
    NetworkManager-libnm

dnf -y install libfreeaptx

dnf5 -y install --enable-repo="*rpmfusion*" \
  libaacs

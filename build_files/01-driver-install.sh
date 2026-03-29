#!/usr/bin/env bash

set -xeuo pipefail

trap 'dnf config-manager setopt keepcache=0' EXIT

dnf -y --enablerepo copr:copr.fedorainfracloud.org:lizardbyte:beta install \
  Sunshine

dnf5 -y remove \
    pipewire-config-raop \
    mesa-va-drivers

declare -A toswap=( \
    ["copr:copr.fedorainfracloud.org:ublue-os:bazzite"]="wireplumber" \
    ["copr:copr.fedorainfracloud.org:ublue-os:bazzite-multilib"]="pipewire bluez NetworkManager" \
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

dnf5 -y install --enable-repo="*rpmfusion*" --disable-repo="*fedora-multimedia*" \
  libaacs \
  libbdplus \
  libbluray \
  libbluray-utils

dnf -y --enablerepo=terra --enablerepo=terra-extras install \
  terra-gamescope

dnf -y --enablerepo=terra install --skip-unavailable \
  asusctl \
  gamescope-session-ogui-steam \
  gamescope-session-opengamepadui \
  gamescope-session-plus \
  gamescope-session-steam \
  inputplumber \
  opengamepadui \
  powerbuttond \
  powerstation \
  ScopeBuddy \
  scx-scheds \
  scx-tools \
  steam-notif-daemon \
  steamos-manager \
  steamos-manager-gamescope-session-plus \
  umu-launcher

if [[ "${BUILD_FLAVOR}" =~ "nvidia" ]] ; then
  dnf -y --enablerepo=terra --enablerepo=terra-nvidia --enablerepo=terra-mesa install \
    -x falcond \
    steam
else
  dnf -y --enablerepo=terra --enablerepo=terra-mesa install \
    -x falcond \
    steam
fi


rm /usr/share/wayland-sessions/gamescope-session-steam.desktop # we dont want the standard session

mkdir -p /usr/share/sdl/
curl "https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/refs/heads/master/gamecontrollerdb.txt" -Lo /usr/share/sdl/gamecontrollerdb.txt

dnf install -y mangohud vulkan-tools waydroid

dnf info mesa-filesystem | grep -F -e "Terra"
rpm -qa | grep -v -E "^gamescope" &> /dev/null

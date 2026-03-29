#!/usr/bin/env bash

set -xeuo pipefail

trap 'dnf config-manager setopt keepcache=0' EXIT

dnf -y --enablerepo copr:copr.fedorainfracloud.org:lizardbyte:beta install \
  Sunshine

dnf -y install \
    vulkan-tools \
    waydroid
sed -i~ -E 's/=.\$\(command -v (nft|ip6?tables-legacy).*/=/g' /usr/lib/waydroid/data/scripts/waydroid-net.sh

# dnf -y --enablerepo=terra --enablerepo=terra-extras install \
#   terra-gamescope

dnf -y --enablerepo=terra-mesa install \
    gamescope.x86_64 \
    gamescope-libs.x86_64 \
    gamescope-shaders \
    dbus-x11 \
    evtest \
    asusctl \
    inputplumber \
    opengamepadui \
    powerstation \
    ScopeBuddy \
    scx-scheds \
    scx-tools \
    steam-notif-daemon \
    steamos-manager \
    steamos-manager-gamescope-session-plus \
    libFAudio.x86_64 \
    vkBasalt.x86_64 \
    mangohud.x86_64 \
    obs-vkcapture.x86_64 \
    obs-glcapture.x86_64 \
    openxr \
    gamescope-libs.i686 \
    vkBasalt.i686 \
    libFAudio.i686 \
    mangohud.i686 \
    obs-vkcapture.i686 \
    obs-glcapture.i686 \
    umu-launcher

if [[ "${BUILD_FLAVOR}" =~ "nvidia" ]] ; then
  dnf -y --enablerepo=terra --enablerepo=terra-nvidia --enablerepo=terra-mesa --setopt=install_weak_deps=False install \
    -x falcond \
    steam \
    lutris
else
  dnf -y --enablerepo=terra-mesa --setopt=install_weak_deps=False install \
    -x falcond \
    steam \
    lutris
fi
dnf -y remove \
    gamemode

/ctx/ghcurl "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" -Lo /usr/bin/winetricks && \
    chmod +x /usr/bin/winetricks && \
    setfattr -n user.component -v "winetricks" /usr/bin/winetricks

mkdir -p /usr/share/sdl/
curl "https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/refs/heads/master/gamecontrollerdb.txt" -Lo /usr/share/sdl/gamecontrollerdb.txt

dnf info mesa-filesystem | grep -F -e "Terra"
rpm -qa | grep -v -E "^gamescope" &> /dev/null
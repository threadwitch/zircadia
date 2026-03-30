#!/usr/bin/env bash

set -xeuo pipefail

trap 'dnf config-manager setopt keepcache=0' EXIT

dnf -y --enablerepo copr:copr.fedorainfracloud.org:lizardbyte:beta install \
  Sunshine

dnf -y --enablerepo=terra --enablerepo=terra-extras --enablerepo=terra-mesa --from-repo=terra install \
    terra-gamescope \
    terra-gamescope-libs.x86_64 \
    terra-gamescope-libs.i686 \
    gamescope-session \
    inputplumber \
    opengamepadui \
    powerstation \
    ScopeBuddy \
    steam-notif-daemon \
    steamos-manager \
    umu-launcher

dnf -y install \
    dbus-x11 \
    evtest \
    asusctl \
    scx-scheds \
    scx-tools \
    libFAudio.x86_64 \
    vkBasalt.x86_64 \
    mangohud \
    obs-studio-plugin-vkcapture \
    openxr \
    vkBasalt.i686 \
    libFAudio.i686 \
    waydroid \
    vulkan-tools


if [[ "${BUILD_FLAVOR}" =~ "nvidia" ]] ; then
  dnf -y --enablerepo=terra --enablerepo=terra-nvidia --enablerepo=terra-mesa --setopt=install_weak_deps=False install \
    -x falcond \
    steam \
    faugus
else
  dnf -y --enablerepo=terra-mesa --setopt=install_weak_deps=False install \
    -x falcond \
    steam \
    faugus
fi
dnf -y remove \
    gamemode

curl "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" -Lo /usr/bin/winetricks && \
    chmod +x /usr/bin/winetricks && \
    setfattr -n user.component -v "winetricks" /usr/bin/winetricks

mkdir -p /usr/share/sdl/
curl "https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/refs/heads/master/gamecontrollerdb.txt" -Lo /usr/share/sdl/gamecontrollerdb.txt

dnf info mesa-filesystem | grep -F -e "Terra"
rpm -qa | grep -v -E "^gamescope" &> /dev/null
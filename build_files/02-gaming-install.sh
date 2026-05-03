#!/usr/bin/env bash

set -xeuo pipefail

trap 'dnf config-manager setopt keepcache=0' EXIT

# dnf -y --enablerepo copr:copr.fedorainfracloud.org:lizardbyte:beta install \
# 	Sunshine

dnf -y --enablerepo=terra --enablerepo=terra-mesa install \
	terra-gamescope.x86_64 \
	terra-gamescope-libs.x86_64 \
	terra-gamescope-libs.i686 \
	inputplumber \
	powerstation \
	ScopeBuddy \
	steam-notif-daemon \
	steamos-manager \
	scx-scheds \
	scx-tools \
	asusctl \
	libFAudio.x86_64 \
	libFAudio.i686 \
	vkBasalt.x86_64 \
	vkBasalt.i686 \
	dbus-x11 \
	evtest \
	mangohud \
	obs-studio-plugin-vkcapture-hook-libs.x86_64 \
	obs-studio-plugin-vkcapture-hook-libs.i686 \
	openxr \
	umu-launcher

dnf -y --setopt=install_weak_deps=False install \
	waydroid \
	vulkan-tools

if [[ "${BUILD_FLAVOR}" =~ "nvidia" ]]; then
	dnf -y --enablerepo=terra --enablerepo=terra-nvidia --enablerepo=terra-mesa --setopt=install_weak_deps=False install \
		-x falcond \
		steam
else
	dnf -y --enablerepo=terra --enablerepo=terra-mesa --setopt=install_weak_deps=False install \
		-x falcond \
		steam
fi
dnf -y remove \
	gamemode

dnf -y copr enable faugus/faugus-launcher
dnf -y install faugus-launcher
dnf -y copr disable faugus/faugus-launcher

curl "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" -Lo /usr/bin/winetricks &&
	chmod +x /usr/bin/winetricks &&
	setfattr -n user.component -v "winetricks" /usr/bin/winetricks

mkdir -p /usr/share/sdl/
curl "https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/refs/heads/master/gamecontrollerdb.txt" -Lo /usr/share/sdl/gamecontrollerdb.txt

# dnf info mesa-filesystem | grep -F -e "Terra"
rpm -qa | grep -v -E "^gamescope" &>/dev/null

#!/usr/bin/env bash

set -xeuo pipefail

# dnf -y --enablerepo copr:copr.fedorainfracloud.org:lizardbyte:beta install \
# 	Sunshine

# Fedora 45 currently has no Terra full fdk-aac build. Use Fedora's native
# library consistently instead of pinning an unavailable or cross-release RPM.
# Align both architectures before Steam's dependency solve. Do not versionlock
# the codec or exclude Fedora's package. Full HE/HEv2 FDK support can be revisited
# explicitly when a compatible Terra package becomes available.
dnf -y upgrade fdk-aac-free.x86_64
fdk_aac_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}' fdk-aac-free.x86_64)"
dnf -y install "fdk-aac-free-${fdk_aac_version}.i686"

dnf -y --enablerepo=terra --enablerepo=terra-mesa --enablerepo=terra-extras install \
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

# Steam pulls NSS's 32-bit libraries. Upgrade the native package first, then
# install the exact same build for i686; otherwise a stale base and current
# Fedora Updates can own the same architecture-independent man pages at
# different versions and fail the RPM transaction.
dnf -y upgrade nss.x86_64
nss_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}' nss.x86_64)"
dnf -y install "nss-${nss_version}.i686"

dnf -y --enablerepo=terra --enablerepo=terra-mesa --setopt=install_weak_deps=False install \
	-x falcond \
	steam
dnf -y remove \
	gamemode

# faugus-launcher is delivered as a Flatpak (Layer 4) via
# system_files/usr/share/flatpak/preinstall.d/faugus.preinstall — do not also
# install the RPM here.

curl "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" -Lo /usr/bin/winetricks &&
	chmod +x /usr/bin/winetricks &&
	setfattr -n user.component -v "winetricks" /usr/bin/winetricks

mkdir -p /usr/share/sdl/
curl "https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/refs/heads/master/gamecontrollerdb.txt" -Lo /usr/share/sdl/gamecontrollerdb.txt

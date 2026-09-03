#!/usr/bin/env bash

set -xeuo pipefail

# dnf -y --enablerepo copr:copr.fedorainfracloud.org:lizardbyte:beta install \
# 	Sunshine

# The full FDK AAC codec is in Terra Multimedia. Steam pulls a 32-bit media
# stack, so install the same pinned Terra build for both architectures before
# dependency solving can select Fedora's feature-reduced fdk-aac-free instead.
# Terra's RPM currently provides but does not conflict with fdk-aac-free; swap
# either architecture explicitly when an updated base happens to ship it.
fdk_aac_version="2.0.3-1.fc44"
for arch in x86_64 i686; do
	if rpm -q "fdk-aac-free.${arch}" >/dev/null 2>&1; then
		dnf -y --enablerepo=terra-multimedia swap \
			"fdk-aac-free.${arch}" \
			"fdk-aac-${fdk_aac_version}.${arch}"
	fi
done
dnf -y --enablerepo=terra-multimedia install \
	"fdk-aac-${fdk_aac_version}.x86_64" \
	"fdk-aac-${fdk_aac_version}.i686"
dnf versionlock add fdk-aac.x86_64 fdk-aac.i686

# Pinning fdk-aac does not hide the differently named Fedora alternative.
# Keep later transactions on the selected codec family.
dnf -y config-manager setopt exclude=fdk-aac-free

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

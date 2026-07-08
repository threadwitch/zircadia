#!/usr/bin/env bash

set -ouex pipefail

#### Variables

# Can be "beta" or "stable"
RELEASE_CHANNEL="${ONEPASSWORD_RELEASE_CHANNEL:-stable}"

# Must be over 1000
GID_ONEPASSWORD="${GID_ONEPASSWORD:-1500}"

# Must be over 1000
GID_ONEPASSWORDCLI="${GID_ONEPASSWORDCLI:-1600}"

echo "Installing 1Password"

# On libostree systems, /opt is a symlink to /var/opt,
# which actually only exists on the live system. /var is
# a separate mutable, stateful FS that's overlaid onto
# the ostree rootfs. Therefore we need to install it into
# /usr/lib/1Password instead, and dynamically create a
# symbolic link /opt/1Password => /usr/lib/1Password upon
# boot.

# Prepare staging directory
mkdir -p /var/opt # -p just in case it exists
# for some reason...

# 1Password's RPM writes its GUI payload below /opt/1Password. On bootc
# images, /opt is normally a symlink to /var/opt, while this build step mounts
# /var as tmpfs. Make /opt a real staging directory for this RUN so the RPM
# payload is written into the image layer, then restore the original symlink
# after relocating the payload to /usr/lib/1Password.
OPT_WAS_SYMLINK="false"
OPT_SYMLINK_TARGET=""
if [ -L /opt ]; then
	OPT_WAS_SYMLINK="true"
	OPT_SYMLINK_TARGET="$(readlink /opt)"
	rm /opt
	mkdir -p /opt
fi

# Setup repo
cat <<EOF >/etc/yum.repos.d/1password.repo
[1password]
name=1Password ${RELEASE_CHANNEL^} Channel
baseurl=https://downloads.1password.com/linux/rpm/${RELEASE_CHANNEL}/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

# Import signing key
rpmkeys --import https://downloads.1password.com/linux/keys/1password.asc

# Now let's install the packages.
dnf -y install 1password 1password-cli

# Clean up the yum repo (updates are baked into new images)
rm /etc/yum.repos.d/1password.repo -f

# And then we do the hacky dance!
#
# Find the payload after install. The normal path is /opt/1Password because
# /opt was staged as a real directory above, but keep /var/opt and /usr/lib
# fallbacks so future base-image/package layout changes fail gracefully.
ONEPASSWORD_SOURCE=""
for candidate in /opt/1Password /var/opt/1Password /usr/lib/1Password; do
	resolved="$(readlink -f "${candidate}" 2>/dev/null || true)"
	if [ -n "${resolved}" ] && [ -d "${resolved}" ] && [ -e "${resolved}/1password" ]; then
		ONEPASSWORD_SOURCE="${resolved}"
		break
	fi
done

case "${ONEPASSWORD_SOURCE}" in
	"")
		echo "Unable to find installed 1Password payload after RPM install." >&2
		echo "RPM file list:" >&2
		rpm -ql 1password >&2 || true
		echo "Observed candidate directories:" >&2
		find /opt /var/opt /usr/lib -maxdepth 2 -type d -name '1Password' -print >&2 || true
		exit 1
		;;
	/usr/lib/1Password)
		echo "1Password payload already installed at /usr/lib/1Password"
		;;
	*)
		echo "Relocating 1Password payload from ${ONEPASSWORD_SOURCE} to /usr/lib/1Password"
		rm -rf /usr/lib/1Password
		mkdir -p /usr/lib
		mv "${ONEPASSWORD_SOURCE}" /usr/lib/1Password
		;;
	esac

if [ "${OPT_WAS_SYMLINK}" = "true" ]; then
	rmdir /opt
	ln -s "${OPT_SYMLINK_TARGET}" /opt
fi

if [ ! -x /usr/lib/1Password/1password ]; then
	echo "1Password binary missing after relocation" >&2
	find /usr/lib/1Password -maxdepth 2 -type f -print >&2 || true
	exit 1
fi

# Create a symlink /usr/bin/1password => /usr/lib/1Password/1password
rm -f /usr/bin/1password
ln -s /usr/lib/1Password/1password /usr/bin/1password

#####
# The following is a bastardization of "after-install.sh"
# which is normally packaged with 1password. You can compare with
# /usr/lib/1Password/after-install.sh if you want to see.

cd /usr/lib/1Password

# chrome-sandbox requires the setuid bit to be specifically set.
# See https://github.com/electron/electron/issues/17972
chmod 4755 /usr/lib/1Password/chrome-sandbox

# Normally, after-install.sh would create a group,
# "onepassword", right about now. But if we do that during
# the ostree build it'll disappear from the running system!
# I'm going to work around that by hardcoding GIDs and
# crossing my fingers that nothing else steps on them.
# These numbers _should_ be okay under normal use, but
# if there's a more specific range that I should use here
# please submit a PR!

# Specifically, GID must be > 1000, and absolutely must not
# conflict with any real groups on the deployed system.
# Normal user group GIDs on Fedora are sequential starting
# at 1000, so let's skip ahead and set to something higher.

# BrowserSupport binary needs setgid. This gives no extra permissions to the binary.
# It only hardens it against environmental tampering.
BROWSER_SUPPORT_PATH="/usr/lib/1Password/1Password-BrowserSupport"

# Add .desktop file and icons
if [ -d /usr/share/applications ]; then
	# xdg-desktop-menu will only be available if xdg-utils is installed, which is likely but not guaranteed
	if [ -n "$(which xdg-desktop-menu)" ]; then
		xdg-desktop-menu install --mode system --novendor /usr/lib/1Password/resources/1password.desktop
		xdg-desktop-menu forceupdate
	else
		install -m0644 /usr/lib/1Password/resources/1password.desktop /usr/share/applications
	fi
fi
if [ -d /usr/share/icons ]; then
	cp -rf /usr/lib/1Password/resources/icons/* /usr/share/icons/
	# Update icon cache
	gtk-update-icon-cache -f -t /usr/share/icons/hicolor/
fi

chgrp "${GID_ONEPASSWORD}" "${BROWSER_SUPPORT_PATH}"
chmod g+s "${BROWSER_SUPPORT_PATH}"

# onepassword-cli also needs its own group and setgid, like the other helpers.
chgrp "${GID_ONEPASSWORDCLI}" /usr/bin/op
chmod g+s /usr/bin/op

# Dynamically create the required groups via sysusers.d
# and set the GID based on the files we just chgrp'd
cat >/usr/lib/sysusers.d/onepassword.conf <<EOF
g onepassword ${GID_ONEPASSWORD}
EOF
cat >/usr/lib/sysusers.d/onepassword-cli.conf <<EOF
g onepassword-cli ${GID_ONEPASSWORDCLI}
EOF

# remove the sysusers.d entries created by onepassword RPMs.
# They don't magically set the GID like we need them to.
rm -f /usr/lib/sysusers.d/30-rpmostree-pkg-group-onepassword.conf
rm -f /usr/lib/sysusers.d/30-rpmostree-pkg-group-onepassword-cli.conf

# Register path symlink
# We do this via tmpfiles.d so that it is created by the live system.
cat >/usr/lib/tmpfiles.d/onepassword.conf <<EOF
L  /opt/1Password  -  -  -  -  /usr/lib/1Password
EOF

cat >/etc/1password/custom_allowed_browsers <<EOF
helium
EOF
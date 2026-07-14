#!/usr/bin/env bash

set -ouex pipefail

#### Variables

# Can be "beta" or "stable"
RELEASE_CHANNEL="${ONEPASSWORD_RELEASE_CHANNEL:-stable}"

# Must be over 1000
GID_ONEPASSWORD="${GID_ONEPASSWORD:-1500}"

# Must be over 1000
GID_ONEPASSWORDCLI="${GID_ONEPASSWORDCLI:-1600}"

# Must be over 1000
GID_ONEPASSWORDMCP="${GID_ONEPASSWORDMCP:-1501}"

echo "Installing 1Password"

# Older 1Password RPMs installed the GUI payload below /opt/1Password.
# Newer Fedora builds install it below /usr/share/1password and put helper
# binaries in /usr/libexec. We support both layouts because the vendor package
# layout has changed under us.
#
# On bootc/ostree images, /opt is normally a symlink to /var/opt, while this
# build step mounts /var as tmpfs. If an older RPM still writes below /opt,
# make /opt a real staging directory for this RUN so its payload is written into
# the image layer, then restore the original symlink after relocation.
mkdir -p /var/opt
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

# Find the GUI payload after install. Current 1Password RPMs on Fedora own
# /usr/share/1password, while older vendor RPMs owned /opt/1Password.
ONEPASSWORD_APP_DIR=""
for candidate in /usr/share/1password /opt/1Password /var/opt/1Password /usr/lib/1Password; do
	resolved="$(readlink -f "${candidate}" 2>/dev/null || true)"
	if [ -n "${resolved}" ] && [ -d "${resolved}" ] && [ -e "${resolved}/1password" ]; then
		ONEPASSWORD_APP_DIR="${resolved}"
		break
	fi
done

case "${ONEPASSWORD_APP_DIR}" in
	"")
		echo "Unable to find installed 1Password payload after RPM install." >&2
		echo "RPM file list:" >&2
		rpm -ql 1password >&2 || true
		echo "Observed candidate directories:" >&2
		find /opt /var/opt /usr/lib /usr/share -maxdepth 2 \( -iname '1Password' -o -iname '1password' \) -print >&2 || true
		exit 1
		;;
	/usr/share/1password)
		echo "1Password payload installed at /usr/share/1password"
		;;
	/usr/lib/1Password)
		echo "1Password payload already installed at /usr/lib/1Password"
		;;
	*)
		echo "Relocating legacy 1Password payload from ${ONEPASSWORD_APP_DIR} to /usr/lib/1Password"
		rm -rf /usr/lib/1Password
		mkdir -p /usr/lib
		mv "${ONEPASSWORD_APP_DIR}" /usr/lib/1Password
		ONEPASSWORD_APP_DIR="/usr/lib/1Password"
		;;
	esac

if [ "${OPT_WAS_SYMLINK}" = "true" ]; then
	rmdir /opt
	ln -s "${OPT_SYMLINK_TARGET}" /opt
fi

if [ ! -x "${ONEPASSWORD_APP_DIR}/1password" ]; then
	echo "1Password binary missing after payload detection" >&2
	find "${ONEPASSWORD_APP_DIR}" -maxdepth 2 -type f -print >&2 || true
	exit 1
fi

# Older RPMs needed this symlink after relocation. Newer RPMs own a wrapper at
# /usr/bin/1password already; do not replace it unless it is missing/broken.
if [ ! -x /usr/bin/1password ]; then
	ln -sf "${ONEPASSWORD_APP_DIR}/1password" /usr/bin/1password
fi

#####
# The following is a bastardization of "after-install.sh"
# which is normally packaged with 1password.

cd "${ONEPASSWORD_APP_DIR}"

# chrome-sandbox requires the setuid bit to be specifically set.
# See https://github.com/electron/electron/issues/17972
chmod 4755 "${ONEPASSWORD_APP_DIR}/chrome-sandbox"

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
BROWSER_SUPPORT_PATH=""
for candidate in /usr/libexec/1Password-BrowserSupport "${ONEPASSWORD_APP_DIR}/1Password-BrowserSupport"; do
	if [ -x "${candidate}" ]; then
		BROWSER_SUPPORT_PATH="${candidate}"
		break
	fi
done
if [ -z "${BROWSER_SUPPORT_PATH}" ]; then
	echo "Unable to find 1Password BrowserSupport helper" >&2
	rpm -ql 1password >&2 || true
	exit 1
fi

MCP_BINARY_PATH=""
for candidate in /usr/libexec/onepassword-mcp "${ONEPASSWORD_APP_DIR}/onepassword-mcp"; do
	if [ -x "${candidate}" ]; then
		MCP_BINARY_PATH="${candidate}"
		break
	fi
done

# Add .desktop file and icons when they are not already installed by the RPM.
if [ -d /usr/share/applications ] && [ ! -e /usr/share/applications/1password.desktop ]; then
	# xdg-desktop-menu will only be available if xdg-utils is installed, which is likely but not guaranteed
	if [ -n "$(which xdg-desktop-menu)" ]; then
		xdg-desktop-menu install --mode system --novendor "${ONEPASSWORD_APP_DIR}/resources/1password.desktop"
		xdg-desktop-menu forceupdate
	else
		install -m0644 "${ONEPASSWORD_APP_DIR}/resources/1password.desktop" /usr/share/applications
	fi
fi
if [ -d /usr/share/icons ] && [ -d "${ONEPASSWORD_APP_DIR}/resources/icons" ]; then
	cp -rn "${ONEPASSWORD_APP_DIR}/resources/icons/"* /usr/share/icons/ || true
	# Update icon cache
	gtk-update-icon-cache -f -t /usr/share/icons/hicolor/
fi

chgrp "${GID_ONEPASSWORD}" "${BROWSER_SUPPORT_PATH}"
chmod g+s "${BROWSER_SUPPORT_PATH}"

if [ -n "${MCP_BINARY_PATH}" ]; then
	chgrp "${GID_ONEPASSWORDMCP}" "${MCP_BINARY_PATH}"
	chmod g+s "${MCP_BINARY_PATH}"
fi

# onepassword-cli also needs its own group and setgid, like the other helpers.
chgrp "${GID_ONEPASSWORDCLI}" /usr/bin/op
chmod g+s /usr/bin/op

# Dynamically create the required groups via sysusers.d
# and set the GID based on the files we just chgrp'd
cat >/usr/lib/sysusers.d/1password.conf <<EOF
g onepassword ${GID_ONEPASSWORD}
g onepassword-mcp ${GID_ONEPASSWORDMCP}
EOF
cat >/usr/lib/sysusers.d/1password-cli.conf <<EOF
g onepassword-cli ${GID_ONEPASSWORDCLI}
EOF

# Remove older rpm-ostree-generated sysusers.d entries if present.
rm -f /usr/lib/sysusers.d/30-rpmostree-pkg-group-onepassword.conf
rm -f /usr/lib/sysusers.d/30-rpmostree-pkg-group-onepassword-cli.conf
rm -f /usr/lib/sysusers.d/onepassword.conf
rm -f /usr/lib/sysusers.d/onepassword-cli.conf

# Register /opt compatibility symlink for older hard-coded integrations.
# We do this via tmpfiles.d so that it is created by the live system.
cat >/usr/lib/tmpfiles.d/onepassword.conf <<EOF
L  /opt/1Password  -  -  -  -  ${ONEPASSWORD_APP_DIR}
EOF

mkdir -p /etc/1password
cat >/etc/1password/custom_allowed_browsers <<EOF
helium
EOF
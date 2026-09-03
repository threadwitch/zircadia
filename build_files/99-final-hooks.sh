#!/usr/bin/env bash

set -xeuo pipefail

sed -i -f - /usr/lib/os-release <<EOF
s|^NAME=.*|NAME=\"Zircadia\"|
s|^PRETTY_NAME=.*|PRETTY_NAME=\"Zircadia\"|
EOF

# Disable the Terra repos in the shipped repo files so bootc-image-builder's
# depsolve does not try to verify their file:// GPG keys.
#
# dnf5 `config-manager setopt` only writes an override to
# /etc/dnf/repos.override.d/, which BIB's osbuild depsolve does NOT read (it
# reads /etc/yum.repos.d/ directly), so setopt does not stop BIB from choking on
# Terra's file:// keys. Editing the repo files is what BIB honors. This runs
# after all install steps, which enable Terra transiently via --enablerepo, so
# disabling here is safe.
sed -i 's/^enabled=1/enabled=0/' \
	/etc/yum.repos.d/terra.repo \
	/etc/yum.repos.d/terra-extras.repo \
	/etc/yum.repos.d/terra-mesa.repo \
	/etc/yum.repos.d/terra-multimedia.repo

cp -avf "/ctx/files"/. /

echo 'import "/usr/share/zirconium/just/67-gamerslop.just"' >> /usr/share/zirconium/just/00-start.just

KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"
export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

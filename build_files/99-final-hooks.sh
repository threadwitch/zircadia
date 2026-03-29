#!/usr/bin/env bash

set -xeuo pipefail

sed -i -f - /usr/lib/os-release <<EOF
s|^NAME=.*|NAME=\"Zircadia\"|
s|^PRETTY_NAME=.*|PRETTY_NAME=\"Zircadia\"|
EOF

for repo in \
    fedora-cisco-openh264 \
    fedora-steam \
    fedora-rar \
    google-chrome \
    tailscale \
    _copr_ublue-os-akmods \
    terra \
    terra-extras \
    negativo17-fedora-uld \
    negativo17-fedora-multimedia; \
do \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/$repo.repo; \
done && for copr in \
    ublue-os/bazzite \
    ublue-os/bazzite-multilib \
    ublue-os/staging \
    ublue-os/packages \
    ublue-os/obs-vkcapture \
    ycollet/audinux \
    ublue-os/hhd \
    lizardbyte/beta \
    che/nerd-fonts; \
do \
    dnf -y copr disable $copr; \
done && unset -v copr

systemctl --global disable sunshine.service
systemctl disable waydroid-container.service

echo 'import "/usr/share/zirconium/just/67-gamerslop.just"' >> /usr/share/zirconium/just/00-start.just

KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"
export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright 2025-2026 The Secureblue Authors
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
shopt -s nullglob

ARCH="$(uname -m)"

curl -fLsS --retry 5 -o /etc/yum.repos.d/repo.secureblue.dev.secureblue.repo https://repo.secureblue.dev/secureblue.repo

secureblue_gpg_key_path="$(dnf repo info secureblue --json | jq -r '.[0].gpg_key.[0]')"
rpmkeys --import "${secureblue_gpg_key_path}"

dnf -y --best --repo=secureblue install trivalent trivalent-selinux

sed -i 's/org\.mozilla\.firefox\.desktop/trivalent.desktop/' /usr/share/applications/mimeapps.list

dnf -y copr enable secureblue/packages
dnf -y install trivalent-subresource-filter
dnf -y copr disable secureblue/packages
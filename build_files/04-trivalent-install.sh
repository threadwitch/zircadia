#!/usr/bin/bash

set -xeuo pipefail

# "borrowing" from https://github.com/tulilirockz/sysext-trivalent/blob/main/install-trivalent.sh
curl -fLsS --retry 5 -o /etc/yum.repos.d/repo.secureblue.dev.secureblue.repo https://repo.secureblue.dev/secureblue.repo

dnf --best --repo=secureblue -y install trivalent

secureblue_gpg_key_path="$(dnf repo info secureblue --json | jq -r '.[0].gpg_key.[0]')"

rpmkeys --import "${secureblue_gpg_key_path}"

# stuff im taking from the secureblue project lol
dnf -y copr enable secureblue/packages
dnf -y copr disable secureblue/packages
dnf -y --enablerepo copr:copr.fedorainfracloud.org:secureblue:packages install \
	trivalent-subresource-filter

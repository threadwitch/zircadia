#!/usr/bin/env bash
set -euo pipefail

# The repository-reviewed digest is the bootstrap trust anchor. Do not execute
# an older Cosign binary or trust a checksum fetched with the binary at runtime.
# renovate: datasource=github-release-attachments depName=sigstore/cosign
cosign_version="v3.1.4"
cosign_url="https://github.com/sigstore/cosign/releases/download/${cosign_version}/cosign-linux-amd64"
cosign_sha256="424e2c97d0b45fd7a6b608a87f090f35633f4c23ece5f092d48bba11aaf4bbfa"

# Both current publishing jobs are Linux amd64, including the Alpine job.
# Fail closed instead of silently installing the wrong architecture.
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    echo "Unsupported Cosign platform; add a reviewed release digest first." >&2
    exit 1
fi
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_PATH:?GITHUB_PATH is required}"

download_dir="$(mktemp -d "${RUNNER_TEMP}/cosign-download.XXXXXX")"
trap 'rm -rf "${download_dir}"' EXIT
curl --fail --silent --show-error --location --retry 3 \
    --proto '=https' --proto-redir '=https' \
    "${cosign_url}" -o "${download_dir}/cosign"
printf '%s  %s\n' "${cosign_sha256}" "${download_dir}/cosign" |
    sha256sum --check --strict

install_dir="${RUNNER_TEMP}/zircadia-cosign-bin"
install -Dm 0755 "${download_dir}/cosign" "${install_dir}/cosign"
"${install_dir}/cosign" version --json
printf '%s\n' "${install_dir}" >> "${GITHUB_PATH}"

#!/usr/bin/env bash

set -euo pipefail

# Temporary Fedora 44 override for the eMudhra incident. Keep this independent
# of the base-image pin and remove it once the base includes the remediation.
# https://bodhi.fedoraproject.org/updates/FEDORA-2026-56e14eb520
# Koji build 3124620, signed with Fedora 44's existing key (6d9f90a6).
ca_certificates_version="2026.2.92_v9.0.319-1.fc44"
ca_certificates_sha256="3de32ead7049b1c06f5cbc821d7991051f5d54afd044f2db8b0529584d9d36b3"
ca_certificates_url="https://kojipkgs.fedoraproject.org/packages/ca-certificates/2026.2.92_v9.0.319/1.fc44/data/signed/6d9f90a6/noarch/ca-certificates-${ca_certificates_version}.noarch.rpm"

if [[ "$(rpm --eval '%{fedora}')" != 44 ]]; then
    echo "The ca-certificates override is only approved for Fedora 44." >&2
    exit 1
fi

# Compare with RPM's own EVR rules, including epochs; never downgrade a newer
# upstream bundle. Pass values as environment data rather than Lua source.
check_installed_version() {
    installed_version="$(rpm -q --queryformat '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' ca-certificates)"
    version_comparison="$(INSTALLED_CA_EVR="${installed_version}" \
        REQUIRED_CA_EVR="0:${ca_certificates_version}" \
        rpm --eval '%{lua:print(rpm.vercmp(os.getenv("INSTALLED_CA_EVR"), os.getenv("REQUIRED_CA_EVR")))}')"
    case "${version_comparison}" in
        -1|0|1) ;;
        *) echo "Could not compare the installed ca-certificates version." >&2; exit 1 ;;
    esac
}

check_installed_version
temporary_directory="$(mktemp -d)"
trap 'rm -rf "${temporary_directory}"' EXIT
if [[ "${version_comparison}" == -1 ]]; then
    package="${temporary_directory}/ca-certificates.rpm"
    curl --fail --show-error --location --retry 3 --proto '=https' --tlsv1.2 \
        "${ca_certificates_url}" --output "${package}"
    printf '%s  %s\n' "${ca_certificates_sha256}" "${package}" | sha256sum --check --strict
    # Do not import keys or accept an unsigned / unknown-key package. DNF also
    # checks the local RPM; gpgcheck alone does not protect local packages.
    rpmkeys --checksig --verbose "${package}"
    dnf -y --disablerepo='*' --setopt=gpgcheck=1 \
        --setopt=localpkg_gpgcheck=1 --setopt=install_weak_deps=False \
        upgrade "${package}"
fi

check_installed_version
if [[ "${version_comparison}" == -1 ]]; then
    echo "Expected ca-certificates >= ${ca_certificates_version}, got ${installed_version}." >&2
    exit 1
fi

# Regenerate extracted bundles using normal Fedora policy. This preserves
# administrator-provided anchors and blocklists; do not rewrite custom inputs.
update-ca-trust
# Check certificate identities, not mutable labels. These SHA-256 fingerprints
# are from the two removal patches in Fedora's source commit
# 1ccf8e36dcf991db7ae4a4220c1612d1f43d96ec (AAA and emSign ECC Root CA - G3).
# A custom anchor restoring either root fails the build but is NOT removed.
trust extract --filter=ca-anchors --purpose=server-auth --format=pem-directory \
    --overwrite "${temporary_directory}/anchors"
shopt -s nullglob
anchors=("${temporary_directory}/anchors/"*.pem)
if (( ${#anchors[@]} == 0 )); then
    echo "No TLS trust anchors were extracted; refusing an unverified trust store." >&2
    exit 1
fi
for certificate in "${anchors[@]}"; do
    fingerprint="$(openssl x509 -in "${certificate}" -noout -fingerprint -sha256)"
    fingerprint="${fingerprint#*=}"
    fingerprint="${fingerprint//:/}"
    fingerprint="${fingerprint,,}"
    if [[ ! "${fingerprint}" =~ ^[0-9a-f]{64}$ ]]; then
        echo "Could not fingerprint a TLS trust anchor." >&2
        exit 1
    fi
    case "${fingerprint}" in
        d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4|\
        86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b)
            echo "An affected CA is still a TLS trust anchor; review custom trust inputs without deleting them automatically." >&2
            exit 1
            ;;
    esac
done
printf 'Verified ca-certificates %s\n' "${installed_version}"

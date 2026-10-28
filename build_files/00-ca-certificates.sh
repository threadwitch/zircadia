#!/usr/bin/env bash

set -euo pipefail

# Temporary Fedora 44 override for the eMudhra incident. Keep this independent
# of the base-image pin. Fedora 45 must inherit its own corrected package.
# https://bodhi.fedoraproject.org/updates/FEDORA-2026-0609e13c0d
# Koji build 3125414, signed with Fedora 44's existing key (6d9f90a6).
ca_certificates_version="2026.2.92_v9.0.319-2.fc44"
ca_certificates_sha256="ce1202707eb5df4bb506202c94f4fdc948a51ab044e7f7ead3ddd5e54dd8bde5"
ca_certificates_url="https://kojipkgs.fedoraproject.org/packages/ca-certificates/2026.2.92_v9.0.319/2.fc44/data/signed/6d9f90a6/noarch/ca-certificates-${ca_certificates_version}.noarch.rpm"

fedora_version="$(rpm --eval '%{fedora}')"
case "${fedora_version}" in
    44) ;; # The signed, checksummed fallback above is Fedora 44 only.
    45) ca_certificates_version="2026.2.92_v9.0.319-2.fc45" ;;
    *) echo "CA remediation is only approved for Fedora 44 and 45." >&2; exit 1 ;;
esac

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
    if [[ "${fedora_version}" != 44 ]]; then
        echo "Fedora 45 must inherit ca-certificates >= ${ca_certificates_version}; no cross-release fallback is permitted." >&2
        exit 1
    fi
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
# Check identities, not mutable labels. Fedora source commit
# 8cd553919e44c0859c528132905846c86874b211 includes the removal patches for
# AAA, emSign ECC Root CA - G3, and the additional emSign Root CS CA - G3.
# Extract each purpose separately: plain PEM cannot represent purpose policy.
# A custom anchor restoring any affected root fails the build but is NOT removed.
shopt -s nullglob
for purpose in server-auth code-signing; do
    trust extract --filter=ca-anchors --purpose="${purpose}" --format=pem-directory \
        --overwrite "${temporary_directory}/${purpose}"
    anchors=("${temporary_directory}/${purpose}/"*.pem)
    # An empty code-signing set is valid (nothing is trusted for that purpose).
    # Keep the existing TLS sanity check; extraction failures always fail closed.
    if [[ "${purpose}" == server-auth ]] && (( ${#anchors[@]} == 0 )); then
        echo "No TLS trust anchors were extracted; refusing an unverified trust store." >&2
        exit 1
    fi
    for certificate in "${anchors[@]}"; do
        fingerprint="$(openssl x509 -in "${certificate}" -noout -fingerprint -sha256)"
        fingerprint="${fingerprint#*=}"
        fingerprint="${fingerprint//:/}"
        fingerprint="${fingerprint,,}"
        if [[ ! "${fingerprint}" =~ ^[0-9a-f]{64}$ ]]; then
            echo "Could not fingerprint a ${purpose} trust anchor." >&2
            exit 1
        fi
        case "${fingerprint}" in
            d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4|\
            86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b|\
            f2edaaff3d9b701fb4d14c9f285f8c0bad90fc3bcc1fa07d47f4718edaba34a5)
                echo "An affected CA is still a ${purpose} trust anchor; review custom trust inputs without deleting them automatically." >&2
                exit 1
                ;;
        esac
    done
    printf 'Verified %s trust anchors: %s checked; affected CA fingerprints absent\n' \
        "${purpose}" "${#anchors[@]}"
done
printf 'Verified ca-certificates %s\n' "${installed_version}"

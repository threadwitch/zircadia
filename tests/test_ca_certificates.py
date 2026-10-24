"""Offline fail-closed checks for the isolated Fedora CA package override."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "build_files/00-ca-certificates.sh"
VERSION = "2026.2.92_v9.0.319-2.fc44"
OLD_VERSION = "2026.2.92_v9.0.319-1.fc44"
AFFECTED_ROOTS = [
    "d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4",
    "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b",
    "f2edaaff3d9b701fb4d14c9f285f8c0bad90fc3bcc1fa07d47f4718edaba34a5",
]


class CaCertificatesTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.mocks = self.root / "mocks"
        self.mocks.mkdir()
        self.downloads = self.root / "downloads"
        self.downloads.mkdir()
        self.log = self.root / "commands.jsonl"
        self.state = self.root / "installed"
        self.state.write_text(OLD_VERSION)
        fixture = self.root / "fixture.rpm"
        fixture.write_bytes(b"signed RPM fixture for orchestration tests\n")
        script = SCRIPT.read_text()
        checksum = hashlib.sha256(fixture.read_bytes()).hexdigest()
        script = re.sub(r'ca_certificates_sha256="[a-f0-9]+"',
                        f'ca_certificates_sha256="{checksum}"', script)
        self.script = self.root / "install.sh"
        self.script.write_text(script)
        mock = self.mocks / "mock"
        mock.write_text('''#!/usr/bin/env python3
import json, os, pathlib, shutil, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\\n")
state = pathlib.Path(os.environ["INSTALLED_STATE"])
if name == "rpm":
    if args == ["--eval", "%{fedora}"]:
        print(os.environ.get("FEDORA", "44"))
    elif args[0] == "--eval":
        if os.environ.get("COMPARE_FAIL") == "1": sys.exit(1)
        if os.environ.get("COMPARE_INVALID") == "1":
            print("unknown")
        else:
            current = os.environ["INSTALLED_CA_EVR"]
            target = os.environ["REQUIRED_CA_EVR"]
            print((current > target) - (current < target))
    else:
        if os.environ.get("QUERY_FAIL") == "1": sys.exit(1)
        print("0:" + state.read_text(), end="")
elif name == "curl":
    if os.environ.get("DOWNLOAD_FAIL") == "1": sys.exit(22)
    destination = pathlib.Path(args[args.index("--output") + 1])
    shutil.copyfile(os.environ["FIXTURE_RPM"], destination)
    if os.environ.get("CORRUPT") == "1": destination.write_bytes(b"corrupt")
elif name == "rpmkeys":
    if os.environ.get("SIGNATURE_FAIL") == "1": sys.exit(1)
elif name == "dnf":
    if os.environ.get("DNF_FAIL") == "1": sys.exit(1)
    state.write_text(os.environ.get("RESULT_VERSION", "2026.2.92_v9.0.319-2.fc44"))
elif name == "update-ca-trust":
    if os.environ.get("TRUST_FAIL") == "1": sys.exit(1)
elif name == "trust":
    if os.environ.get("TRUST_LIST_FAIL") == "1": sys.exit(1)
    purpose = next(arg.split("=", 1)[1] for arg in args if arg.startswith("--purpose="))
    if os.environ.get("TRUST_FAIL_PURPOSE") == purpose: sys.exit(1)
    destination = pathlib.Path(args[-1])
    destination.mkdir()
    empty = os.environ.get("EMPTY_TRUST") == "1"
    if purpose == "code-signing":
        empty = os.environ.get("EMPTY_CODE_SIGNING") == "1"
    if not empty:
        (destination / "custom-label.pem").write_text("anchor fixture")
elif name == "openssl":
    if os.environ.get("OPENSSL_FAIL") == "1": sys.exit(1)
    purpose = pathlib.Path(args[args.index("-in") + 1]).parent.name
    if os.environ.get("OPENSSL_FAIL_PURPOSE") == purpose: sys.exit(1)
    key = "CODE_SIGNING_ANCHOR" if purpose == "code-signing" else "ANCHOR"
    fingerprint = os.environ.get(key, "ab" * 32)
    print("sha256 Fingerprint=" + fingerprint)
else:
    raise AssertionError(name)
''')
        mock.chmod(0o755)
        for name in ["rpm", "curl", "rpmkeys", "dnf", "update-ca-trust", "trust", "openssl"]:
            (self.mocks / name).symlink_to(mock)
        self.environment = dict(os.environ, PATH=f"{self.mocks}:{os.environ['PATH']}",
                                TMPDIR=str(self.downloads), COMMAND_LOG=str(self.log),
                                INSTALLED_STATE=str(self.state), FIXTURE_RPM=str(fixture))

    def run_install(self, **extra):
        self.log.write_text("")
        result = subprocess.run(["bash", str(self.script)],
                                env=dict(self.environment, **extra),
                                capture_output=True, text=True, check=False)
        self.commands = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(list(self.downloads.iterdir()), [], "temporary RPM leaked")
        return result

    def called(self, name):
        return [command for command in self.commands if command[0] == name]

    def test_verified_package_is_only_transaction_input(self):
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        dnf = self.called("dnf")
        self.assertEqual(len(dnf), 1)
        self.assertEqual(dnf[0][1:-1], ["-y", "--disablerepo=*", "--setopt=gpgcheck=1",
                         "--setopt=localpkg_gpgcheck=1", "--setopt=install_weak_deps=False",
                         "upgrade"])
        self.assertTrue(dnf[0][-1].endswith("/ca-certificates.rpm"))
        self.assertLess(self.commands.index(self.called("rpmkeys")[0]),
                        self.commands.index(dnf[0]))
        curl = self.called("curl")[0]
        self.assertIn("=https", curl)
        self.assertTrue(any(arg.startswith("https://kojipkgs.fedoraproject.org/")
                            and "/2.fc44/data/signed/6d9f90a6/noarch/" in arg
                            and arg.endswith(f"ca-certificates-{VERSION}.noarch.rpm")
                            for arg in curl))
        self.assertEqual(len(self.called("update-ca-trust")), 1)
        self.assertEqual(self.state.read_text(), VERSION)

    def test_corrected_base_does_not_download_or_transact(self):
        self.state.write_text(VERSION)
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.called("curl"))
        self.assertFalse(self.called("dnf"))
        self.assertTrue(self.called("update-ca-trust"))

    def test_wrong_fedora_release_fails_before_download(self):
        result = self.run_install(FEDORA="45")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.called("curl"))
        self.assertFalse(self.called("dnf"))

    def test_missing_installed_package_fails_closed(self):
        result = self.run_install(QUERY_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.called("curl"))

    def test_failed_download_never_transacts(self):
        result = self.run_install(DOWNLOAD_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.called("rpmkeys"))
        self.assertFalse(self.called("dnf"))

    def test_checksum_mismatch_never_checks_or_installs_package(self):
        result = self.run_install(CORRUPT="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.called("rpmkeys"))
        self.assertFalse(self.called("dnf"))

    def test_rejected_signature_never_transacts(self):
        result = self.run_install(SIGNATURE_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.called("dnf"))

    def test_failed_transaction_stops_build(self):
        result = self.run_install(DNF_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.called("update-ca-trust"))

    def test_old_resulting_version_stops_build(self):
        result = self.run_install(RESULT_VERSION=OLD_VERSION)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Expected ca-certificates >=", result.stderr)
        self.assertFalse(self.called("update-ca-trust"))

    def test_newer_base_is_preserved_without_download_or_transaction(self):
        self.state.write_text("2026.2.93_v9.0.320-1.fc44")
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.called("curl"))
        self.assertFalse(self.called("dnf"))
        self.assertTrue(self.called("trust"))

    def test_comparison_failure_or_unexpected_output_fails_closed(self):
        for flag in ["COMPARE_FAIL", "COMPARE_INVALID"]:
            with self.subTest(flag=flag):
                result = self.run_install(**{flag: "1"})
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.called("curl"))
                self.assertFalse(self.called("dnf"))

    def test_affected_root_even_with_a_custom_label_fails_without_removing_it(self):
        self.state.write_text(VERSION)
        for anchor in AFFECTED_ROOTS:
            # Exercise the usual uppercase, colon-separated OpenSSL format too.
            fingerprint = ":".join(anchor[i:i+2].upper() for i in range(0, 64, 2))
            with self.subTest(anchor=anchor):
                result = self.run_install(ANCHOR=fingerprint)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("review custom trust inputs", result.stderr)
                self.assertEqual(len(self.called("trust")), 1)
                self.assertEqual(self.called("trust")[0][1:-1],
                                 ["extract", "--filter=ca-anchors", "--purpose=server-auth",
                                  "--format=pem-directory", "--overwrite"])
                self.assertFalse(self.called("dnf"))

    def test_code_signing_roots_are_checked_separately_from_tls(self):
        self.state.write_text(VERSION)
        for anchor in AFFECTED_ROOTS:
            fingerprint = ":".join(anchor[i:i+2].upper() for i in range(0, 64, 2))
            with self.subTest(anchor=anchor):
                result = self.run_install(CODE_SIGNING_ANCHOR=fingerprint)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("code-signing trust anchor", result.stderr)
                self.assertIn("review custom trust inputs", result.stderr)
                self.assertEqual(len(self.called("trust")), 2)
                self.assertEqual(self.called("trust")[1][1:-1],
                                 ["extract", "--filter=ca-anchors", "--purpose=code-signing",
                                  "--format=pem-directory", "--overwrite"])
                self.assertFalse(self.called("dnf"))

    def test_empty_code_signing_store_is_valid_after_successful_extraction(self):
        result = self.run_install(EMPTY_CODE_SIGNING="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Verified code-signing trust anchors: 0 checked", result.stdout)
        self.assertEqual(len(self.called("trust")), 2)

    def test_code_signing_extraction_and_fingerprint_errors_fail_closed(self):
        for extra in [{"TRUST_FAIL_PURPOSE": "code-signing"},
                      {"OPENSSL_FAIL_PURPOSE": "code-signing"},
                      {"CODE_SIGNING_ANCHOR": "invalid"}]:
            with self.subTest(extra=extra):
                result = self.run_install(**extra)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Verified ca-certificates", result.stdout)

    def test_healthy_store_checks_both_purposes(self):
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Verified server-auth trust anchors: 1 checked", result.stdout)
        self.assertIn("Verified code-signing trust anchors: 1 checked", result.stdout)
        self.assertEqual(len(self.called("trust")), 2)

    def test_empty_trust_store_or_fingerprint_failure_fails_closed(self):
        for extra in [{"EMPTY_TRUST": "1"}, {"OPENSSL_FAIL": "1"}, {"ANCHOR": "invalid"}]:
            with self.subTest(extra=extra):
                result = self.run_install(**extra)
                self.assertNotEqual(result.returncode, 0)

    def test_trust_query_failure_fails_closed(self):
        result = self.run_install(TRUST_LIST_FAIL="1")
        self.assertNotEqual(result.returncode, 0)

    def test_failed_trust_extraction_stops_build(self):
        result = self.run_install(TRUST_FAIL="1")
        self.assertNotEqual(result.returncode, 0)

    def test_override_runs_before_other_network_install_steps(self):
        containerfile = (ROOT / "Containerfile").read_text()
        self.assertLess(containerfile.index("/ctx/build/00-ca-certificates.sh"),
                        containerfile.index("/ctx/build/01-source-fetch.sh"))
        self.assertTrue(SCRIPT.stat().st_mode & 0o111)

    def test_no_key_import_repo_configuration_or_custom_trust_edits(self):
        script = SCRIPT.read_text()
        for unsafe in ["--nogpgcheck", "--nodeps", "--allowerasing", "--import",
                       "config-manager", "--enablerepo", "/etc/pki/ca-trust/source"]:
            self.assertNotIn(unsafe, script)
        checksum = re.search(r'ca_certificates_sha256="([a-f0-9]+)"', script)[1]
        self.assertEqual(len(checksum), 64)


if __name__ == "__main__":
    unittest.main()

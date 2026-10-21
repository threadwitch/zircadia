"""Offline, fail-closed checks for the checksum-pinned Cosign bootstrap."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / ".github/actions/install-cosign/install.sh").read_text()


def dependency_matches(content):
    matches = []
    for line in (ROOT / ".github/renovate.json5").read_text().splitlines():
        if not line.strip().startswith('"datasource='):
            continue
        pattern = json.loads(line.strip().removesuffix(","))
        pattern = re.sub(r"\(\?<([a-zA-Z]+)>", r"(?P<\1>", pattern)
        matches.extend(match for match in re.finditer(pattern, content)
                       if match["depName"] == "sigstore/cosign")
    return matches


class CosignConfigurationTests(unittest.TestCase):
    def test_renovate_tracks_version_and_checksum_together(self):
        matches = dependency_matches(SCRIPT)
        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0]["datasource"], "github-release-attachments")
        self.assertRegex(matches[0]["currentValue"], r"^v[0-9]+\.[0-9]+\.[0-9]+$")
        self.assertRegex(matches[0]["currentDigest"], r"^[a-f0-9]{64}$")
        self.assertEqual(len(dependency_matches(SCRIPT.replace("\n", "\r\n"))), 1)

    def test_missing_or_invalid_digest_is_not_a_version_only_update(self):
        self.assertEqual(dependency_matches(re.sub(r'^cosign_sha256=.*\n', "", SCRIPT, flags=re.M)), [])
        self.assertEqual(dependency_matches(re.sub(r'cosign_sha256="[a-f0-9]+"',
                                                  'cosign_sha256="invalid"', SCRIPT)), [])

    def test_paired_update_changes_only_version_and_digest(self):
        match = dependency_matches(SCRIPT)[0]
        changed = SCRIPT
        replacements = {"currentValue": "v99.2.3", "currentDigest": "a" * 64}
        for group in sorted(replacements, key=match.start, reverse=True):
            start, end = match.span(group)
            changed = changed[:start] + replacements[group] + changed[end:]
        updated = dependency_matches(changed)[0]
        for group, expected in replacements.items():
            self.assertEqual(updated[group], expected)
        self.assertEqual([line for line in SCRIPT.splitlines()
                          if not line.startswith(("cosign_version=", "cosign_sha256="))],
                         [line for line in changed.splitlines()
                          if not line.startswith(("cosign_version=", "cosign_sha256="))])

    def test_both_production_jobs_use_the_verified_local_installer(self):
        workflow = (ROOT / ".github/workflows/build.yml").read_text()
        self.assertEqual(workflow.count("uses: ./.github/actions/install-cosign"), 2)
        self.assertNotIn("uses: sigstore/cosign-installer@", workflow)
        for job in [workflow.split("  manifest:")[0], workflow.split("  manifest:")[1]]:
            self.assertLess(job.index("uses: actions/checkout@"),
                            job.index("uses: ./.github/actions/install-cosign"))
        self.assertEqual(workflow.count("--new-bundle-format=false --use-signing-config=false --key"), 2)


class CosignInstallTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "mocks").mkdir()
        (self.root / "tmp").mkdir()
        self.fixture = self.root / "fixture"
        self.fixture.write_text("#!/usr/bin/env bash\nprintf 'verified fixture\\n'\n")
        curl = self.root / "mocks/curl"
        curl.write_text('#!/usr/bin/env bash\nset -euo pipefail\n'
                        'printf "%s\\n" "$@" > "${CURL_ARGUMENTS}"\n'
                        'if [[ ${FAIL_DOWNLOAD:-0} == 1 ]]; then exit 22; fi\n'
                        'cp "${TEST_BINARY}" "${@: -1}"\n')
        curl.chmod(0o755)
        uname = self.root / "mocks/uname"
        uname.write_text('#!/usr/bin/env bash\n'
                         'if [[ $1 == -s ]]; then echo Linux; else echo "${TEST_ARCH:-x86_64}"; fi\n')
        uname.chmod(0o755)

    def run_install(self, *, corrupt=False, fail_download=False, architecture="x86_64"):
        checksum = "0" * 64 if corrupt else hashlib.sha256(self.fixture.read_bytes()).hexdigest()
        script = re.sub(r'cosign_sha256="[a-f0-9]+"', f'cosign_sha256="{checksum}"', SCRIPT)
        environment = dict(os.environ, RUNNER_TEMP=str(self.root / "tmp"),
                           GITHUB_PATH=str(self.root / "path"), TEST_BINARY=str(self.fixture),
                           CURL_ARGUMENTS=str(self.root / "curl-arguments"), TEST_ARCH=architecture,
                           FAIL_DOWNLOAD=str(int(fail_download)),
                           PATH=f"{self.root / 'mocks'}:{os.environ['PATH']}")
        return subprocess.run(["bash", "-c", script], env=environment,
                              capture_output=True, text=True, check=False)

    def assert_not_installed(self):
        self.assertFalse((self.root / "path").exists())
        self.assertFalse((self.root / "tmp/zircadia-cosign-bin/cosign").exists())
        self.assertEqual(list((self.root / "tmp").iterdir()), [])

    def test_verified_binary_installs_and_exports_path(self):
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("verified fixture", result.stdout)
        self.assertEqual((self.root / "path").read_text(),
                         str(self.root / "tmp/zircadia-cosign-bin") + "\n")
        self.assertEqual(list((self.root / "tmp").glob("cosign-download.*")), [])
        arguments = (self.root / "curl-arguments").read_text().splitlines()
        self.assertEqual(arguments[arguments.index("--proto") + 1], "=https")
        self.assertEqual(arguments[arguments.index("--proto-redir") + 1], "=https")

    def test_checksum_mismatch_never_executes_or_installs(self):
        result = self.run_install(corrupt=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("verified fixture", result.stdout)
        self.assert_not_installed()

    def test_failed_download_never_executes_or_installs(self):
        result = self.run_install(fail_download=True)
        self.assertEqual(result.returncode, 22)
        self.assert_not_installed()

    def test_unsupported_architecture_fails_before_download(self):
        result = self.run_install(architecture="aarch64")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "curl-arguments").exists())
        self.assert_not_installed()


if __name__ == "__main__":
    unittest.main()

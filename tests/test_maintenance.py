"""Offline regression checks for pinned tool installation and installer wiring."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
UTIL_INSTALL = (ROOT / "build_files/05-util-install.sh").read_text()


class MaintenanceConfigurationTests(unittest.TestCase):
    def test_renovate_finds_all_annotated_util_versions(self):
        config = (ROOT / ".github/renovate.json5").read_text()
        # Decode the actual JSON strings, preserving escapes in the regexes.
        patterns = [
            json.loads(line.strip().removesuffix(","))
            for line in config.splitlines()
            if line.strip().startswith('"datasource=')
        ]
        matches = {}
        for pattern in patterns:
            pattern = re.sub(r"\(\?<([a-zA-Z]+)>", r"(?P<\1>", pattern)
            matches.update({m["depName"]: m["currentValue"]
                            for m in re.finditer(pattern, UTIL_INSTALL)})
        expected = {
            "nushell/nushell": "nushell",
            "jj-vcs/jj": "jj",
            "age-plugin-yubikey": "age_plugin_yubikey",
            "Foxboron/age-plugin-tpm": "age_plugin_tpm",
            "getsops/sops": "sops",
        }
        self.assertEqual(set(matches), set(expected))
        for dependency, variable in expected.items():
            version = re.search(rf'^{variable}_version="([^"]+)"', UTIL_INSTALL, re.M)
            self.assertEqual(matches[dependency], version[1])

    def test_nushell_install_uses_the_tracked_version(self):
        self.assertIn('"nushell-${nushell_version}"', UTIL_INSTALL)


    def test_onepassword_step_is_disabled_without_removing_security_tools(self):
        containerfile = (ROOT / "Containerfile").read_text()
        self.assertNotIn("/ctx/build/04-1p-install.sh", containerfile)
        self.assertIn("/ctx/build/05-util-install.sh", containerfile)
        for tool in ["pam-u2f", "pam_yubico", "pamu2fcfg", "yubikey-manager",
                     "systemctl enable pcscd.socket", "age-plugin-yubikey"]:
            self.assertIn(tool, UTIL_INSTALL)


class JujutsuInstallTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for name in ["bin", "mocks", "downloads"]:
            (self.root / name).mkdir()
        binary = self.root / "jj"
        binary.write_text("#!/usr/bin/env bash\nprintf 'jj fixture\\n'\n")
        binary.chmod(0o755)
        (self.root / "LICENSE").write_text("fixture license\n")
        self.archive = self.root / "release.tar.gz"
        with tarfile.open(self.archive, "w:gz") as archive:
            archive.add(binary, arcname="./jj")
            archive.add(self.root / "LICENSE", arcname="./LICENSE")
        curl = self.root / "mocks/curl"
        curl.write_text('#!/usr/bin/env bash\nset -euo pipefail\n'
                        'if [[ ${FAIL_DOWNLOAD:-0} == 1 ]]; then exit 22; fi\n'
                        'cp "${TEST_ARCHIVE}" "${@: -1}"\n')
        curl.chmod(0o755)

    def run_install(self, *, corrupt_checksum=False, fail_download=False):
        block = UTIL_INSTALL.split("# renovate: datasource=github-release-attachments depName=jj-vcs/jj\n")[1]
        block = block.split("# Fonts good.")[0]
        checksum = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        if corrupt_checksum:
            checksum = "0" * 64
        block = re.sub(r'jj_sha256="[a-f0-9]+"', f'jj_sha256="{checksum}"', block)
        block = block.replace("/usr/bin/jj", str(self.root / "bin/jj"))
        block = block.replace("/usr/share/licenses/jj/LICENSE", str(self.root / "licenses/jj/LICENSE"))
        environment = dict(os.environ, TMPDIR=str(self.root / "downloads"),
                           TEST_ARCHIVE=str(self.archive), FAIL_DOWNLOAD=str(int(fail_download)),
                           PATH=f"{self.root / 'mocks'}:{self.root / 'bin'}:{os.environ['PATH']}")
        return subprocess.run(["bash", "-euo", "pipefail", "-c", block],
                              env=environment, capture_output=True, text=True, check=False)

    def test_verified_archive_installs_binary_and_license(self):
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("jj fixture", result.stdout)
        self.assertTrue((self.root / "bin/jj").is_file())
        self.assertTrue((self.root / "licenses/jj/LICENSE").is_file())
        self.assertEqual(list((self.root / "downloads").iterdir()), [])

    def test_checksum_mismatch_fails_before_installing(self):
        result = self.run_install(corrupt_checksum=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAILED", result.stdout)
        self.assertFalse((self.root / "bin/jj").exists())
        self.assertEqual(list((self.root / "downloads").iterdir()), [])

    def test_failed_download_fails_before_installing(self):
        result = self.run_install(fail_download=True)
        self.assertEqual(result.returncode, 22)
        self.assertFalse((self.root / "bin/jj").exists())
        self.assertEqual(list((self.root / "downloads").iterdir()), [])


if __name__ == "__main__":
    unittest.main()

"""Offline regression checks for paired Renovate release-asset updates."""

import json
from pathlib import Path
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
UTIL_INSTALL = (ROOT / "build_files/05-util-install.sh").read_text()
CONFIG = (ROOT / ".github/renovate.json5").read_text()


def dependency_matches(content):
    matches = []
    for line in CONFIG.splitlines():
        if not line.strip().startswith('"datasource='):
            continue
        pattern = json.loads(line.strip().removesuffix(","))
        pattern = re.sub(r"\(\?<([a-zA-Z]+)>", r"(?P<\1>", pattern)
        matches.extend(re.finditer(pattern, content))
    return [match for match in matches if match["depName"] == "jj-vcs/jj"]


class RenovateReleaseAssetTests(unittest.TestCase):
    def test_jj_has_one_dependency_with_version_and_asset_digest(self):
        matches = dependency_matches(UTIL_INSTALL)
        self.assertEqual(len(matches), 1, "Do not also extract a version-only jj dependency")
        dependency = matches[0]
        self.assertEqual(dependency["datasource"], "github-release-attachments")
        self.assertRegex(dependency["currentValue"], r"^v[0-9]+\.[0-9]+\.[0-9]+$")
        checksum = re.search(r'^jj_sha256="([a-f0-9]{64})"$', UTIL_INSTALL, re.M)
        self.assertEqual(dependency["currentDigest"], checksum[1])
        self.assertIn('"versioningTemplate": "semver-coerced"', CONFIG)

    def test_jj_asset_match_supports_crlf(self):
        matches = dependency_matches(UTIL_INSTALL.replace("\n", "\r\n"))
        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0]["currentDigest"], dependency_matches(UTIL_INSTALL)[0]["currentDigest"])

    def test_missing_checksum_does_not_fall_back_to_version_only(self):
        content = re.sub(r'^jj_sha256=.*\n', "", UTIL_INSTALL, flags=re.M)
        self.assertEqual(dependency_matches(content), [])

    def test_invalid_checksum_does_not_fall_back_to_version_only(self):
        content = re.sub(r'jj_sha256="[a-f0-9]+"', 'jj_sha256="invalid"', UTIL_INSTALL)
        self.assertEqual(dependency_matches(content), [])

    def test_version_and_digest_capture_spans_allow_one_paired_update(self):
        dependency = dependency_matches(UTIL_INSTALL)[0]
        updated = UTIL_INSTALL
        replacements = {"currentValue": "v99.2.3", "currentDigest": "a" * 64}
        for group in sorted(replacements, key=lambda name: dependency.start(name), reverse=True):
            start, end = dependency.span(group)
            updated = updated[:start] + replacements[group] + updated[end:]
        matches = dependency_matches(updated)
        self.assertEqual(len(matches), 1)
        for group, value in replacements.items():
            self.assertEqual(matches[0][group], value)
        original_other_lines = [line for line in UTIL_INSTALL.splitlines()
                                if not line.startswith(("jj_version=", "jj_sha256="))]
        updated_other_lines = [line for line in updated.splitlines()
                               if not line.startswith(("jj_version=", "jj_sha256="))]
        self.assertEqual(updated_other_lines, original_other_lines)

    def test_full_release_tag_builds_correct_archive_url(self):
        assignments = re.findall(r'^jj_(?:version|url)=".*"$', UTIL_INSTALL, re.M)
        self.assertEqual(len(assignments), 2)
        result = subprocess.run(
            ["bash", "-euo", "pipefail", "-c", "\n".join(assignments) + '\nprintf "%s" "$jj_url"'],
            capture_output=True, text=True, check=True,
        )
        tag = dependency_matches(UTIL_INSTALL)[0]["currentValue"]
        self.assertEqual(result.stdout,
                         f"https://github.com/jj-vcs/jj/releases/download/{tag}/"
                         f"jj-{tag}-x86_64-unknown-linux-musl.tar.gz")


if __name__ == "__main__":
    unittest.main()

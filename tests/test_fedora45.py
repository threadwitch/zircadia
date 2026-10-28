"""Offline release-transition guards; actual package solving runs in image CI."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class Fedora45Tests(unittest.TestCase):
    def test_build_pins_match_and_unused_fc44_kernel_stage_is_gone(self):
        digest = '9694ac282710ac50c5dde6010ff2fa160cf43f8b6e5ba9b6e3579d1bd6d3bd29'
        for name in ['Justfile', '.github/workflows/build.yml']:
            self.assertIn(digest, (ROOT / name).read_text())
        containerfile = (ROOT / 'Containerfile').read_text()
        self.assertNotIn('FROM ghcr.io/ublue-os/akmods', containerfile)
        self.assertNotIn('fc44', containerfile)

    def test_codec_preflight_requires_both_native_release_architectures(self):
        source = (ROOT / 'build_files/03-gaming-install.sh').read_text()
        block = source[source.index('fedora_version='):source.index('for arch in x86_64 i686; do\n\tif rpm')]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'rpm').write_text('#!/bin/sh\necho "${FEDORA}"\n')
            (root / 'dnf').write_text('''#!/bin/bash
name="${@: -1}"
if [[ "$name" != *"${MISSING:-nothing}" ]]; then echo "$name"; fi
''')
            for f in root.iterdir(): f.chmod(0o755)
            for release, missing, success in [('45', '', True), ('44', '', True),
                                               ('45', 'i686', False), ('46', '', False)]:
                env = dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}', FEDORA=release, MISSING=missing)
                result = subprocess.run(['bash', '-euo', 'pipefail', '-c', block], env=env, capture_output=True)
                self.assertEqual(result.returncode == 0, success, result.stderr)

    def test_final_hooks_cover_vendor_and_legacy_repo_layouts(self):
        source = (ROOT / 'build_files/99-final-hooks.sh').read_text()
        block = source[source.index('for repo in terra '):source.index('\n\ncp -avf')]
        for vendor, legacy in [(True, False), (False, True), (True, True), (False, False)]:
            with self.subTest(vendor=vendor, legacy=legacy), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                directories = [root / 'vendor', root / 'etc']
                for directory, present in zip(directories, [vendor, legacy]):
                    directory.mkdir()
                    if present:
                        for repo in ['terra', 'terra-extras', 'terra-mesa', 'terra-multimedia']:
                            (directory / f'{repo}.repo').write_text(f'[{repo}]\nenabled=1\n')
                script = block.replace('/usr/share/dnf5/repos.d', str(directories[0])).replace('/etc/yum.repos.d', str(directories[1]))
                result = subprocess.run(['bash', '-euo', 'pipefail', '-c', script], capture_output=True)
                self.assertEqual(result.returncode == 0, vendor or legacy, result.stderr)
                if vendor or legacy:
                    for directory in directories:
                        for f in directory.glob('*.repo'): self.assertNotIn('enabled=1', f.read_text())
                    self.assertEqual(len(list(directories[1].glob('*.repo'))), 4)

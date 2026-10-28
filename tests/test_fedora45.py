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

    def test_native_codec_versions_align_without_full_codec_pin(self):
        source = (ROOT / 'build_files/03-gaming-install.sh').read_text()
        self.assertNotIn('exclude=fdk-aac-free', source)
        self.assertNotIn('dnf versionlock add fdk-aac', source)
        self.assertNotIn('2.0.3-1.fc', source)
        block = source[source.index('dnf -y upgrade fdk-aac-free'):source.index('dnf -y --enablerepo=terra --enablerepo=terra-mesa --enablerepo=terra-extras install')]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            log = root / 'calls'
            (root / 'rpm').write_text('#!/bin/sh\nprintf "2.0.3-3.fc45"\n')
            (root / 'dnf').write_text('#!/bin/sh\necho "$*" >> "$LOG"\n')
            for name in ['rpm', 'dnf']: (root / name).chmod(0o755)
            env = dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}', LOG=str(log))
            result = subprocess.run(['bash', '-euo', 'pipefail', '-c', block], env=env, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(log.read_text().splitlines(), [
                '-y upgrade fdk-aac-free.x86_64',
                '-y install fdk-aac-free-2.0.3-3.fc45.i686'])

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

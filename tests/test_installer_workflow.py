"""Offline regression checks for disk-image workflow configuration."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
DISK_WORKFLOW = (ROOT / ".github/workflows/build-disk.yml").read_text()


class InstallerWorkflowTests(unittest.TestCase):
    def test_installer_paths_exist_and_trigger_pull_requests(self):
        config_line = next(line for line in DISK_WORKFLOW.splitlines()
                           if "config-file:" in line)
        paths = re.findall(r"'([^']+\.toml)'", config_line)
        # Podman requires ./ or / to distinguish bind mounts from named volumes.
        self.assertEqual(set(paths), {"./iso.toml", "./disk_config/disk.toml"})
        for path in paths:
            self.assertTrue((ROOT / path).is_file(), path)
            self.assertIn(f"      - '{path.removeprefix('./')}'", DISK_WORKFLOW)
        self.assertIn("      - '.github/workflows/build-disk.yml'", DISK_WORKFLOW)

    def test_installer_always_uses_published_architecture(self):
        self.assertIn("    runs-on: ubuntu-24.04\n", DISK_WORKFLOW)
        self.assertNotIn("inputs.platform", DISK_WORKFLOW)
        self.assertNotIn("arm64", DISK_WORKFLOW)

    def test_installer_builder_matches_local_iso_recipes(self):
        builder = re.search(r'BIB_IMAGE: "([^"]+)"', DISK_WORKFLOW)[1]
        self.assertEqual(builder, "ghcr.io/osbuild/bootc-image-builder:latest")
        self.assertIn(builder, (ROOT / "Justfile").read_text())

    def test_installer_rootfs_is_explicit_for_each_image_type(self):
        self.assertIn(
            "rootfs: ${{ matrix.disk-type == 'anaconda-iso' && 'btrfs' || 'ext4' }}",
            DISK_WORKFLOW,
        )
        justfile = (ROOT / "Justfile").read_text()
        self.assertIn('--rootfs btrfs', justfile)
        self.assertIn('filesystem := env("BUILD_FILESYSTEM", "ext4")', justfile)


if __name__ == "__main__":
    unittest.main()

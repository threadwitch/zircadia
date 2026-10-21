"""Offline regression checks for Renovate scheduling and storage-action tracking."""

import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
STORAGE_ACTION = "ublue-os/container-storage-action"


def read_config() -> dict:
    """Read this config's JSON subset: line comments and trailing commas."""
    content = (ROOT / ".github/renovate.json5").read_text()
    # Preserve quoted strings, including URLs and escaped regex characters.
    content = re.sub(
        r'("(?:\\.|[^"\\])*")|//[^\n]*|,(\s*[}\]])',
        lambda match: match[1] or match[2] or "",
        content,
    )
    return json.loads(content)


class RenovateScheduleTests(unittest.TestCase):
    def test_monday_window_is_global_and_uses_los_angeles_time(self) -> None:
        config = read_config()
        self.assertEqual(config["schedule"], ["before 6am on monday"])
        self.assertEqual(config["timezone"], "America/Los_Angeles")
        for rule in config["packageRules"]:
            self.assertNotIn("schedule", rule)
            self.assertNotIn("timezone", rule)

    def test_storage_action_keeps_a_full_pin_and_trackable_branch(self) -> None:
        workflow = (ROOT / ".github/workflows/build.yml").read_text()
        action_lines = [
            line.strip() for line in workflow.splitlines()
            if f"uses: {STORAGE_ACTION}@" in line
        ]
        self.assertEqual(len(action_lines), 1)
        self.assertRegex(
            action_lines[0],
            rf"^uses: {re.escape(STORAGE_ACTION)}@[a-f0-9]{{40}} # main$",
        )

    def test_storage_action_updates_always_require_review(self) -> None:
        rules = read_config()["packageRules"]
        storage_rules = [
            (index, rule) for index, rule in enumerate(rules)
            if STORAGE_ACTION in rule.get("matchDepNames", [])
        ]
        self.assertEqual(len(storage_rules), 1)
        index, rule = storage_rules[0]
        self.assertEqual(rule["matchManagers"], ["github-actions"])
        self.assertIs(rule["automerge"], False)
        self.assertNotIn("matchUpdateTypes", rule)
        self.assertNotIn("enabled", rule)
        # The specific policy must override the earlier general pin-automerge rule.
        for auto_index, auto_rule in enumerate(rules):
            if auto_rule.get("automerge") is True:
                self.assertLess(auto_index, index)


if __name__ == "__main__":
    unittest.main()

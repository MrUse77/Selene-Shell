"""Structural contracts for the overlay-coordinator foundation slice."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class OverlayFoundationTests(unittest.TestCase):
    def test_singleton_registered_in_qmldir(self):
        qmldir = (ROOT / "Services" / "qmldir").read_text()
        self.assertIn("singleton OverlayCoordinator OverlayCoordinator.qml", qmldir)

    def test_coordinator_private_backing_is_assignable(self):
        src = (ROOT / "Services" / "OverlayCoordinator.qml").read_text()
        self.assertIn("property string _activeKind", src)
        self.assertIn("property var _targetScreen", src)

    def test_coordinator_public_projections_are_readonly(self):
        src = (ROOT / "Services" / "OverlayCoordinator.qml").read_text()
        for name in ("activeKind", "targetScreen", "isOpen", "launcherOpen",
                     "dashboardOpen", "powerOpen", "targetScreenName"):
            self.assertRegex(src, rf"readonly property \w+ {name}\b")

    def test_no_writable_public_properties_in_coordinator(self):
        src = (ROOT / "Services" / "OverlayCoordinator.qml").read_text()
        for line in src.splitlines():
            stripped = line.strip()
            if stripped.startswith("property ") and not stripped.startswith("readonly property "):
                name = stripped.split()[2]
                self.assertTrue(name.startswith("_"),
                                f"writable property {name!r} must be private")


if __name__ == "__main__":
    unittest.main()

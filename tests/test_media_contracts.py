#!/usr/bin/env python3
"""Offline structural contracts for Selene's shared multimedia facade."""

from pathlib import Path
import re
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MEDIA_QML = PROJECT_ROOT / "Services" / "Media.qml"
MEDIA_LOGIC_JS = PROJECT_ROOT / "Services" / "MediaLogic.js"
SERVICES_QMLDIR = PROJECT_ROOT / "Services" / "qmldir"
DASHBOARD_QML = PROJECT_ROOT / "Modules" / "Dashboard" / "Dashboard.qml"
BAR_MEDIA_QML = PROJECT_ROOT / "Modules" / "Bar" / "MediaWidget.qml"


class MediaContracts(unittest.TestCase):
    def read_required(self, path: Path) -> str:
        self.assertTrue(path.exists(), f"required media file is missing: {path}")
        return path.read_text(encoding="utf-8")

    def test_media_singleton_and_pure_logic_are_registered(self) -> None:
        media = self.read_required(MEDIA_QML)
        logic = self.read_required(MEDIA_LOGIC_JS)
        qmldir = self.read_required(SERVICES_QMLDIR)

        self.assertIn("pragma Singleton", media)
        self.assertIn("singleton Media Media.qml", qmldir)
        self.assertNotIn("Quickshell.Services.Mpris", logic)
        for function in ("stableId", "hasMetadata", "choosePlayer", "cyclePlayerId"):
            self.assertRegex(logic, rf"function\s+{function}\s*\(")

    def test_both_consumers_use_shared_media_and_no_active_player_api_remains(self) -> None:
        for path in (DASHBOARD_QML, BAR_MEDIA_QML):
            source = self.read_required(path)
            self.assertIn("Media.player", source, f"{path.name} must consume Media.player")
            self.assertNotIn("Quickshell.Services.Mpris", source)

        offenders = []
        for path in PROJECT_ROOT.rglob("*.qml"):
            if "Mpris.activePlayer" in path.read_text(encoding="utf-8"):
                offenders.append(str(path.relative_to(PROJECT_ROOT)))
        self.assertEqual(offenders, [], f"nonexistent Mpris.activePlayer remains in {offenders}")

    def test_media_singleton_owns_the_only_media_position_ticker(self) -> None:
        media = self.read_required(MEDIA_QML)
        dashboard = self.read_required(DASHBOARD_QML)
        bar = self.read_required(BAR_MEDIA_QML)

        self.assertEqual(len(re.findall(r"\bTimer\s*\{", media)), 1)
        self.assertNotRegex(dashboard, r"\bTimer\s*\{")
        self.assertNotRegex(bar, r"\bTimer\s*\{")
        self.assertRegex(media, r"running\s*:\s*root\.player\s*!==\s*null")
        self.assertIn("positionChanged()", media)

    def test_media_actions_are_capability_gated(self) -> None:
        media = self.read_required(MEDIA_QML)
        expected_guards = {
            "togglePlaying": "canTogglePlaying",
            "previous": "canGoPrevious",
            "next": "canGoNext",
            "seekTo": "canSeek",
        }
        for function, capability in expected_guards.items():
            body = re.search(
                rf"function\s+{function}\s*\([^)]*\)\s*\{{(.*?)\n\s*\}}",
                media,
                re.DOTALL,
            )
            self.assertIsNotNone(body, f"Media.{function} is missing")
            self.assertIn(capability, body.group(1), f"Media.{function} must guard {capability}")
        self.assertIn("positionSupported", media)
        self.assertIn("lengthSupported", media)
        self.assertNotRegex(media, r"function\s+setVolume\b")

    def test_dashboard_has_empty_metadata_and_multiple_player_states(self) -> None:
        source = self.read_required(DASHBOARD_QML)
        self.assertIn('text: "No media players"', source)
        self.assertIn('text: "Nothing playing"', source)
        self.assertIn("Media.playerCount > 1", source)
        self.assertIn("Media.playerIndex + 1", source)
        self.assertIn("Media.selectPreviousPlayer()", source)
        self.assertIn("Media.selectNextPlayer()", source)
        self.assertIn("Media.canSeek", source)
        self.assertIn("StyledSlider", source)

    def test_dashboard_artwork_accepts_any_nonempty_url_and_falls_back_on_error(self) -> None:
        source = self.read_required(DASHBOARD_QML)
        self.assertIn("Image.Error", source)
        self.assertNotIn('startsWith("file://")', source)
        self.assertRegex(source, r"source\s*:\s*root\.player\?\.trackArtUrl\s*\?\?\s*\"\"")


if __name__ == "__main__":
    unittest.main(verbosity=2)

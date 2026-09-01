#!/usr/bin/env python3
"""Offline structural contracts for Selene's optional battery feature."""

from pathlib import Path
import re
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LOGIC = PROJECT_ROOT / "Services" / "BatteryLogic.js"
SERVICE = PROJECT_ROOT / "Services" / "Battery.qml"
SERVICES_QMLDIR = PROJECT_ROOT / "Services" / "qmldir"
BAR_WIDGET = PROJECT_ROOT / "Modules" / "Bar" / "BatteryWidget.qml"
BAR = PROJECT_ROOT / "Modules" / "Bar" / "Bar.qml"
BAR_QMLDIR = PROJECT_ROOT / "Modules" / "Bar" / "qmldir"
DASHBOARD = PROJECT_ROOT / "Modules" / "Dashboard" / "Dashboard.qml"


class BatteryContracts(unittest.TestCase):
    def read_required(self, path: Path) -> str:
        self.assertTrue(path.exists(), f"required battery file is missing: {path}")
        return path.read_text(encoding="utf-8")

    def test_singleton_registration_and_pure_logic(self) -> None:
        service = self.read_required(SERVICE)
        logic = self.read_required(LOGIC)
        qmldir = self.read_required(SERVICES_QMLDIR)

        self.assertIn("pragma Singleton", service)
        self.assertIn("singleton Battery Battery.qml", qmldir)
        self.assertNotIn("Quickshell.Services.UPower", logic)
        self.assertIn('import "BatteryLogic.js" as BatteryLogic', service)

    def test_battery_service_is_the_sole_upower_import(self) -> None:
        offenders = []
        for path in PROJECT_ROOT.rglob("*"):
            if path.suffix not in {".qml", ".js"}:
                continue
            if "Quickshell.Services.UPower" in path.read_text(encoding="utf-8"):
                offenders.append(str(path.relative_to(PROJECT_ROOT)))
        self.assertEqual(offenders, ["Services/Battery.qml"])

    def test_service_uses_physical_devices_and_aggregate_selection(self) -> None:
        service = self.read_required(SERVICE)
        self.assertIn("UPower.devices.values", service)
        self.assertIn("UPower.displayDevice", service)
        self.assertIn("UPower.onBattery", service)
        self.assertIn("BatteryLogic.project", service)
        self.assertNotRegex(service, r"\bTimer\s*\{")
        self.assertNotIn("Process {", service)

    def test_bar_widget_is_registered_placed_and_collapses(self) -> None:
        widget = self.read_required(BAR_WIDGET)
        bar = self.read_required(BAR)
        qmldir = self.read_required(BAR_QMLDIR)

        self.assertIn("BatteryWidget BatteryWidget.qml", qmldir)
        self.assertIn("visible: Battery.available", widget)
        self.assertRegex(widget, r"width\s*:\s*Battery\.available\s*\?")
        self.assertIn("BatteryWidget {}", bar)
        self.assertRegex(bar, r"HardwareWidget\s*\{\s*\}\s*BatteryWidget\s*\{\s*\}")
        self.assertNotIn("Quickshell.Services.UPower", widget)

    def test_dashboard_card_is_between_resources_and_media_and_collapses(self) -> None:
        source = self.read_required(DASHBOARD)
        resources = source.index("// ---- Recursos ----")
        battery = source.index("// ---- Battery ----")
        media = source.index("// ---- Medios ----")

        self.assertLess(resources, battery)
        self.assertLess(battery, media)
        battery_block = source[battery:media]
        self.assertIn("visible: Battery.available", battery_block)
        self.assertRegex(battery_block, r"height\s*:\s*Battery\.available\s*\?")
        self.assertIn("Battery.remainingText", battery_block)
        self.assertIn("Battery.batteryCount > 1", battery_block)
        self.assertIn("Battery.onAc", battery_block)
        self.assertIn("Battery.ratio", battery_block)
        self.assertNotIn("Gauge", battery_block)
        self.assertNotIn("Quickshell.Services.UPower", source)

    def test_consumers_do_not_poll_or_reimplement_battery_selection(self) -> None:
        for path in (BAR_WIDGET, DASHBOARD):
            source = self.read_required(path)
            self.assertNotIn("UPower.devices", source)
            self.assertNotIn("displayDevice", source)
            self.assertNotIn("isLaptopBattery", source)
            self.assertNotIn("timeToEmpty", source)
            self.assertNotIn("timeToFull", source)

        widget = self.read_required(BAR_WIDGET)
        self.assertNotRegex(widget, r"\bTimer\s*\{")


if __name__ == "__main__":
    unittest.main(verbosity=2)

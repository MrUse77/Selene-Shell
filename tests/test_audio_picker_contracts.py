"""Contratos del selector de dispositivo de audio de la barra.

Cubre lo que un test de lógica pura no puede ver: que el popup exista como
superficie flotante bajo la barra, que el clic en el volumen lo abra en vez de
lanzar el mezclador externo, y que el servicio de audio exponga la selección
del sink por defecto.

Los márgenes de la superficie los verifica `test_geometry_contracts.py`, que ya
declara el conjunto de superficies flotantes.
"""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent.parent


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def strip_comments(source: str) -> str:
    """Fuente sin comentarios de línea ni de bloque, respetando strings."""
    out = []
    in_string = False
    quote = ""
    i = 0
    while i < len(source):
        ch = source[i]
        if in_string:
            if ch == "\\" and i + 1 < len(source):
                out.append(source[i:i + 2])
                i += 2
                continue
            if ch == quote:
                in_string = False
            out.append(ch)
            i += 1
            continue
        if ch in "\"'":
            in_string = True
            quote = ch
            out.append(ch)
            i += 1
            continue
        if ch == "/" and source.startswith("//", i):
            while i < len(source) and source[i] != "\n":
                i += 1
            continue
        if ch == "/" and source.startswith("/*", i):
            end = source.find("*/", i + 2)
            i = len(source) if end < 0 else end + 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def qmldir_files(rel: str) -> set:
    """Nombres de archivo declarados en un qmldir (el último campo de cada línea)."""
    entries = set()
    for line in read(rel).splitlines():
        parts = line.split()
        if len(parts) >= 2:
            entries.add(parts[-1])
    return entries


class AudioPickerContracts(unittest.TestCase):

    def test_volume_click_opens_the_picker_instead_of_the_mixer(self):
        source = strip_comments(read("Modules/Bar/AudioWidget.qml"))
        click = re.search(r"onClicked:\s*(\{.*?\}|[^\n]+)", source, re.S)
        self.assertIsNotNone(click, "AudioWidget.qml debe declarar onClicked")
        self.assertIn("ShellState.toggleAudioPicker", click.group(1))
        self.assertNotIn("Commands.audio", source,
                         "el clic ya no lanza el mezclador externo")

    def test_widget_highlights_while_the_picker_is_open(self):
        source = strip_comments(read("Modules/Bar/AudioWidget.qml"))
        self.assertRegex(
            source,
            r"active:\s*ShellState\.audioPickerOpen\s*&&\s*"
            r"ShellState\.audioPickerScreen\s*===",
        )

    def test_picker_popup_is_a_floating_overlay_under_the_bar(self):
        source = strip_comments(read("Modules/Bar/AudioPickerPopup.qml"))
        self.assertIn("WlrLayershell.layer: WlrLayer.Overlay", source)
        self.assertIn("exclusionMode: ExclusionMode.Ignore", source)
        self.assertRegex(source, r"visible:\s*ShellState\.audioPickerOpen")
        self.assertRegex(source, r"focusable:\s*ShellState\.audioPickerOpen")

    def test_picker_popup_dismisses_on_click_outside(self):
        source = strip_comments(read("Modules/Bar/AudioPickerPopup.qml"))
        self.assertRegex(source, r"HyprlandFocusGrab\s*\{")
        self.assertRegex(source, r"onCleared:\s*ShellState\.audioPickerOpen\s*=\s*false")

    def test_picker_selects_a_device_and_closes(self):
        panel = strip_comments(read("Components/AudioPanel.qml"))
        self.assertRegex(panel, r"Audio\.selectSink\(")
        self.assertRegex(panel, r"root\.deviceChosen\(\)")

        popup = strip_comments(read("Modules/Bar/AudioPickerPopup.qml"))
        self.assertRegex(popup, r"onDeviceChosen:\s*ShellState\.audioPickerOpen\s*=\s*false")

    def test_picker_popup_is_mounted_once_per_screen(self):
        source = strip_comments(read("shell.qml"))
        blocks = source.split("Variants {")[1:]
        self.assertTrue(
            any("Quickshell.screens" in block and "AudioPickerPopup" in block
                for block in blocks),
            "shell.qml debe montar AudioPickerPopup en un Variants por pantalla",
        )

    def test_state_owns_the_picker_visibility(self):
        source = strip_comments(read("Services/ShellState.qml"))
        self.assertRegex(source, r"property bool audioPickerOpen")
        self.assertRegex(source, r"property string audioPickerScreen")

        body = re.search(r"function toggleAudioPicker\(screenName, centerX\)\s*\{(.*?)\n    \}",
                         source, re.S)
        self.assertIsNotNone(body, "ShellState.qml debe declarar toggleAudioPicker(screenName, centerX)")
        self.assertIn("audioPickerOpen = false", body.group(1))
        self.assertIn("audioPickerScreen = screenName", body.group(1))
        self.assertIn("audioPickerCenterX = centerX", body.group(1))
        self.assertIn("audioPickerOpen = true", body.group(1))
        self.assertRegex(source, r"property real audioPickerCenterX")

    def test_picker_is_centered_on_the_volume_number(self):
        """El popup se centra en el número de volumen, no se alinea a un borde."""
        popup = strip_comments(read("Modules/Bar/AudioPickerPopup.qml"))
        self.assertIn("ShellState.audioPickerCenterX", popup)
        self.assertRegex(popup, r"centerX\s*-\s*implicitWidth / 2",
                         "el margen izquierdo debe derivar del centro del número")
        self.assertRegex(popup, r"left:\s*leftMargin")
        self.assertNotIn("Geometry.panelRight(", popup)
        self.assertRegex(popup, r"top:\s*Geometry\.panelTop\(gapBelowBar\)")

        widget = strip_comments(read("Modules/Bar/AudioWidget.qml"))
        self.assertRegex(
            widget,
            r"value\.mapToItem\(null, value\.width / 2, 0\)\.x\s*\+\s*Geometry\.barMarginSide",
            "el ancla debe ser el centro del texto del porcentaje, en coordenadas de pantalla",
        )

    def test_bar_module_registers_the_popup_as_a_type(self):
        """Un `qmldir` presente desactiva la síntesis de tipos: el archivo nuevo
        tiene que estar listado o QML falla con 'is not a type'."""
        self.assertIn("AudioPickerPopup.qml", qmldir_files("Modules/Bar/qmldir"))

    def test_bar_module_registers_every_component(self):
        registered = qmldir_files("Modules/Bar/qmldir")
        on_disk = {path.name for path in (ROOT / "Modules/Bar").glob("*.qml")}
        self.assertEqual(
            sorted(on_disk - registered),
            [],
            "componentes de Modules/Bar sin registrar en su qmldir",
        )

    def test_components_module_registers_every_component(self):
        registered = qmldir_files("Components/qmldir")
        on_disk = {path.name for path in (ROOT / "Components").glob("*.qml")}
        self.assertEqual(
            sorted(on_disk - registered),
            [],
            "componentes de Components sin registrar en su qmldir",
        )

    def test_audio_service_exposes_sinks_and_selection(self):
        source = strip_comments(read("Services/Audio.qml"))
        self.assertRegex(source, r"readonly property var sinks:")
        self.assertRegex(
            source,
            r"function selectSink\(node\)\s*\{[^}]*Pipewire\.preferredDefaultAudioSink\s*=\s*node",
        )


if __name__ == "__main__":
    unittest.main()

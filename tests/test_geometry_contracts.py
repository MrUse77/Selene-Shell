#!/usr/bin/env python3
"""Contratos estructurales offline para la geometría declarada de la barra.

Estos checks no prueban el layout real en pantalla. Fijan que la geometría
(alto de barra y márgenes) se declare como servicio resuelto por cadena
(env neutra -> shell.json -> default) en vez de asumirse con literales
repetidos en Bar.qml, y que el consumidor no vuelva a hardcodear esos valores.

La última fase fija el ROL de cada argumento de las llamadas reales (no solo el
orden textual de los identificadores): comparar índices de texto deja pasar una
cadena invertida, un min/max intercambiado o un binding de margen cambiado de
borde siempre que los nombres sigan apareciendo en el archivo.
"""

from pathlib import Path
import json
import re
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
GEOMETRY_LOGIC_JS = PROJECT_ROOT / "Services" / "GeometryLogic.js"
GEOMETRY_QML = PROJECT_ROOT / "Services" / "Geometry.qml"
THEME_QML = PROJECT_ROOT / "Services" / "Theme.qml"
SERVICES_QMLDIR = PROJECT_ROOT / "Services" / "qmldir"
SHELL_JSON = PROJECT_ROOT / "shell.json"
BAR_QML = PROJECT_ROOT / "Modules" / "Bar" / "Bar.qml"
QML_GEOMETRY_TEST = PROJECT_ROOT / "tests" / "geometry" / "tst_geometry_logic.qml"

# Cada valor de geometría: (env neutra, setting derivado, default, MIN, MAX), en
# el orden en que la cadena debe pasarlos a `Theme.pick` / `GeometryLogic.resolve`.
GEOMETRY_CHAINS = (
    ("SHELL_BAR_HEIGHT", "Theme.settingsBarHeight", "defaultBarHeight",
     "MIN_BAR_HEIGHT", "MAX_BAR_HEIGHT"),
    ("SHELL_BAR_MARGIN_TOP", "Theme.settingsBarMarginTop", "defaultBarMarginTop",
     "MIN_MARGIN", "MAX_MARGIN"),
    ("SHELL_BAR_MARGIN_SIDE", "Theme.settingsBarMarginSide", "defaultBarMarginSide",
     "MIN_MARGIN", "MAX_MARGIN"),
)

# Propiedad `settings*` de Theme.qml y el accesor + la clave exactos que lee.
THEME_SETTINGS_KEYS = {
    "settingsThemesRoot": ("Settings.str", "themesRoot"),
    "settingsThemeCommand": ("Settings.str", "themeCommand"),
    "settingsTempSensor": ("Settings.str", "tempSensor"),
    "settingsWorkspacesPerMonitor": ("_numSetting", "workspacesPerMonitor"),
    "settingsBarHeight": ("_numSetting", "barHeight"),
    "settingsBarMarginTop": ("_numSetting", "barMarginTop"),
    "settingsBarMarginSide": ("_numSetting", "barMarginSide"),
}


# ---- Utilidades de lectura estructural ----
# Los contratos de rol comparan las expresiones reales, así que necesitan ver el
# fuente sin comentarios: un comentario que nombra un identificador ya bastó para
# satisfacer una verificación por índice de texto.


def strip_comments(source: str) -> str:
    """Devuelve el fuente sin comentarios de línea (`//`) ni de bloque."""
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


def canonical(text: str) -> str:
    """Forma canónica de una expresión: sin comentarios y con espacios colapsados."""
    return re.sub(r"\s+", " ", strip_comments(text)).strip()


def top_level_arguments(source: str, callee: str) -> list:
    """Argumentos de nivel superior de cada llamada `callee(...)`, en orden.

    Respeta strings y paréntesis anidados, así que una llamada usada como
    argumento (por ejemplo `Theme.pick(...)` dentro de `resolve(...)`) queda
    entera en una sola posición. Los comentarios se descartan: una mención
    comentada de una llamada no es una llamada.
    """
    source = strip_comments(source)
    results = []
    search_from = 0
    needle = callee + "("
    while True:
        start = source.find(needle, search_from)
        if start < 0:
            return results
        i = start + len(needle)
        depth = 1
        args = []
        buf = []
        in_string = False
        quote = ""
        while i < len(source):
            ch = source[i]
            if in_string:
                buf.append(ch)
                if ch == "\\" and i + 1 < len(source):
                    buf.append(source[i + 1])
                    i += 2
                    continue
                if ch == quote:
                    in_string = False
                i += 1
                continue
            if ch in "\"'":
                in_string = True
                quote = ch
                buf.append(ch)
                i += 1
                continue
            if ch in "([{":
                depth += 1
                buf.append(ch)
                i += 1
                continue
            if ch in ")]}":
                depth -= 1
                if depth == 0:
                    args.append("".join(buf))
                    i += 1
                    break
                buf.append(ch)
                i += 1
                continue
            if ch == "," and depth == 1:
                args.append("".join(buf))
                buf = []
                i += 1
                continue
            buf.append(ch)
            i += 1
        results.append(args)
        search_from = i


def braced_blocks(source: str, pattern: str) -> list:
    """Cuerpos (sin las llaves) de cada bloque cuya cabecera matchea `pattern`.

    El patrón debe llegar hasta la llave de apertura; las llaves se cuentan con
    un balance simple que ignora strings y comentarios.
    """
    clean = strip_comments(source)
    bodies = []
    for match in re.finditer(pattern, clean):
        open_idx = clean.find("{", match.start())
        if open_idx < 0:
            continue
        depth = 0
        in_string = False
        quote = ""
        i = open_idx
        while i < len(clean):
            ch = clean[i]
            if in_string:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    in_string = False
            elif ch in "\"'":
                in_string = True
                quote = ch
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    bodies.append(clean[open_idx + 1:i])
                    break
            i += 1
    return bodies


class GeometryContracts(unittest.TestCase):
    def read_required(self, path: Path) -> str:
        self.assertTrue(path.exists(), f"required geometry file is missing: {path}")
        return path.read_text(encoding="utf-8")

    # ---- Fase A: el servicio de geometría ----

    def test_shell_json_declares_geometry_keys(self) -> None:
        """shell.json declara las claves de geometría y null significa "usar el default"."""
        settings = json.loads(self.read_required(SHELL_JSON))
        for key in ("barHeight", "barMarginTop", "barMarginSide"):
            self.assertIn(key, settings, f"shell.json debe declarar {key}")
            self.assertIsNone(
                settings[key],
                f"{key} debe ser null (usa el default) o un entero configurable",
            )

    def test_theme_declares_geometry_settings_properties(self) -> None:
        """Los settings numéricos viajan como strings declaradas en Theme.qml.

        Contrato duro: toda referencia `Theme.settingsX` fuera de Theme.qml debe
        nombrar una propiedad declarada, o evalúa a undefined y la cadena cae
        siempre al default.
        """
        theme_source = self.read_required(THEME_QML)
        declared = set(re.findall(r"readonly\s+property\s+string\s+(settings\w+)\b", theme_source))
        for name in ("settingsBarHeight", "settingsBarMarginTop", "settingsBarMarginSide"):
            self.assertIn(name, declared, f"Theme.qml debe declarar la propiedad derivada {name}")

    def test_geometry_singleton_is_registered(self) -> None:
        qmldir = self.read_required(SERVICES_QMLDIR)
        self.assertRegex(
            qmldir,
            r"singleton\s+Geometry\s+Geometry\.qml",
            "Services/qmldir debe registrar el singleton Geometry",
        )

    def test_geometry_service_is_a_singleton_bound_to_the_pure_logic(self) -> None:
        geometry = self.read_required(GEOMETRY_QML)
        self.assertIn("pragma Singleton", geometry)
        self.assertRegex(geometry, re.compile(r"^Item\s*\{", re.MULTILINE))
        self.assertIn('import "GeometryLogic.js" as GeometryLogic', geometry)
        # Mismo criterio que test_selene_corrections: la cadena puede MENCIONAR
        # el archivo en su comentario, pero no puede apuntarle una lectura.
        self.assertNotRegex(
            geometry,
            r"path:\s*[^\n]*shell\.json",
            "Geometry.qml no puede apuntar una lectura a shell.json: el único lector "
            "es Services/Settings.qml",
        )

    def test_each_geometry_chain_is_env_then_setting_then_default(self) -> None:
        """La env de nombre neutro precede al setting, y el default va último.

        Sin este orden, un valor de shell.json podría ganarle a la variable de
        entorno (o el default a ambos) sin que nada lo delate.
        """
        geometry = self.read_required(GEOMETRY_QML)
        chains = (
            ("SHELL_BAR_HEIGHT", "Theme.settingsBarHeight", "defaultBarHeight"),
            ("SHELL_BAR_MARGIN_TOP", "Theme.settingsBarMarginTop", "defaultBarMarginTop"),
            ("SHELL_BAR_MARGIN_SIDE", "Theme.settingsBarMarginSide", "defaultBarMarginSide"),
        )
        for env_name, setting, default in chains:
            with self.subTest(key=default):
                neutral = geometry.index(f'Quickshell.env("{env_name}")')
                setting_index = geometry.index(setting, neutral)
                self.assertLess(
                    neutral, setting_index,
                    f'La env de nombre neutro {env_name} debe preceder a {setting} en la cadena',
                )
                default_index = geometry.index(default, setting_index)
                self.assertLess(
                    setting_index, default_index,
                    f"{default} debe ser el último argumento de la cadena (después del setting)",
                )

    def test_geometry_service_uses_the_logic_and_its_ranges(self) -> None:
        geometry = self.read_required(GEOMETRY_QML)
        self.assertRegex(geometry, r"GeometryLogic\.resolve\s*\(")
        for constant in ("MIN_BAR_HEIGHT", "MAX_BAR_HEIGHT", "MIN_MARGIN", "MAX_MARGIN"):
            self.assertRegex(
                geometry,
                rf"GeometryLogic\.{constant}\b",
                f"Geometry.qml debe acotar con GeometryLogic.{constant}",
            )

    def test_geometry_defaults_reproduce_the_previous_layout(self) -> None:
        """Los defaults son el layout histórico exacto, no una interpretación nueva."""
        geometry = self.read_required(GEOMETRY_QML)
        for name, value in (
            ("defaultBarHeight", 44),
            ("defaultBarMarginTop", 10),
            ("defaultBarMarginSide", 14),
        ):
            self.assertRegex(
                geometry,
                rf"readonly\s+property\s+int\s+{name}\s*:\s*{value}\b",
                f"{name} debe declararse como {value} (reproduce el layout previo)",
            )

    def test_geometry_logic_is_pure(self) -> None:
        """El módulo de geometría no puede depender de singletons ni del shell.

        Los comentarios (incluido el header) pueden nombrar Quickshell o el
        shell.json como origen del valor; lo que no puede existir es la
        dependencia en código, así que se evalúa el archivo sin comentarios.
        """
        code = re.sub(r"//[^\n]*", "", self.read_required(GEOMETRY_LOGIC_JS))
        self.assertNotRegex(code, r"\bimport\b", "GeometryLogic.js debe ser puro, sin imports")
        for reference in ("Quickshell", "Theme.", "Settings."):
            self.assertNotIn(
                reference, code,
                f"GeometryLogic.js no puede referenciar {reference}: el valor crudo "
                "entra como argumento de resolve()",
            )

    def test_geometry_logic_exposes_resolve_and_its_ranges(self) -> None:
        logic = self.read_required(GEOMETRY_LOGIC_JS)
        self.assertRegex(logic, r"function\s+resolve\s*\(\s*raw\s*,\s*fallback\s*,\s*min\s*,\s*max\s*\)")
        # Las constantes pueden exponerse como valor o como función; los dos
        # casos valen, pero el número tiene que estar.
        for name, value in (
            ("MIN_BAR_HEIGHT", 34),
            ("MAX_BAR_HEIGHT", 96),
            ("MIN_MARGIN", 0),
            ("MAX_MARGIN", 200),
        ):
            self.assertRegex(
                logic,
                rf"(?:const|let|var)\s+{name}\s*=\s*{value}\b|function\s+{name}\s*\([^)]*\)\s*\{{\s*return\s+{value}\b",
                f"GeometryLogic.js debe exponer {name} = {value} (como valor o como función)",
            )

    # ---- Fase B: la barra consume el servicio ----

    def test_bar_margins_bind_to_geometry_without_digit_literals(self) -> None:
        bar = self.read_required(BAR_QML)
        block = re.search(r"margins\s*\{(.*?)\n    \}", bar, re.DOTALL)
        self.assertIsNotNone(block, "Bar.qml debe declarar su bloque de márgenes")
        margins = block.group(1)
        self.assertIn(
            "Geometry.barMarginTop", margins,
            "El margen superior de la barra debe venir de Geometry.barMarginTop",
        )
        self.assertIn(
            "Geometry.barMarginSide", margins,
            "Los márgenes laterales de la barra deben venir de Geometry.barMarginSide",
        )
        self.assertNotRegex(
            margins,
            r"\d",
            "El bloque de márgenes no puede conservar literales numéricos",
        )

    def test_bar_height_and_exclusive_zone_come_from_geometry(self) -> None:
        bar = self.read_required(BAR_QML)
        self.assertNotIn("implicitHeight: 44", bar, "El alto de la barra no puede ser un literal")
        self.assertNotIn(
            "exclusiveZone: 44", bar,
            "La zona exclusiva no puede repetir el alto como literal independiente",
        )
        self.assertRegex(
            bar,
            r"implicitHeight\s*:\s*Geometry\.barHeight\b",
            "El alto de la barra debe venir de Geometry.barHeight",
        )
        self.assertRegex(
            bar,
            r"exclusiveZone\s*:\s*implicitHeight\b",
            "La zona exclusiva ES el alto de la barra: debe derivarse de implicitHeight",
        )

    # ---- Fase C: el ROL de cada argumento de las llamadas reales ----
    # Los contratos de la fase A comparan índices de texto: eso deja pasar una
    # cadena invertida (le gana el setting a la env), un min/max intercambiado o
    # un binding de margen movido de borde. Acá se lee la lista de argumentos
    # real de cada llamada, sin comentarios, y se compara posición por posición.

    def test_each_geometry_chain_passes_env_then_setting_then_empty_to_pick(self) -> None:
        """`Theme.pick` recibe (env neutra, setting derivado, ""), en ese orden.

        El rol del primer argumento es la env y el del segundo es el setting: si
        se invierten, un valor de shell.json le gana a la variable de entorno
        aunque el archivo siga nombrando a los dos.
        """
        geometry = self.read_required(GEOMETRY_QML)
        picks = top_level_arguments(geometry, "Theme.pick")
        self.assertEqual(
            len(picks), 3,
            "Geometry.qml debe encadenar exactamente 3 llamadas a Theme.pick (una por valor), "
            f"pero se encontraron {len(picks)}",
        )
        for env_name, setting, _default, _min, _max in GEOMETRY_CHAINS:
            env_call = f'Quickshell.env("{env_name}")'
            with self.subTest(env=env_name):
                matching = [
                    args for args in picks
                    if len(args) == 3 and canonical(args[0]) == env_call
                ]
                self.assertEqual(
                    len(matching), 1,
                    f"Theme.pick de {env_name} debe recibir la env de nombre neutro "
                    f"{env_call} como primer argumento (hoy ningún Theme.pick abre con esa llamada)",
                )
                args = matching[0]
                self.assertEqual(
                    canonical(args[1]), setting,
                    f"El segundo argumento del Theme.pick de {env_name} debe ser el setting "
                    f"derivado {setting} (primer argumento: env; segundo: setting)",
                )
                self.assertEqual(
                    canonical(args[2]), '""',
                    f"El último argumento del Theme.pick de {env_name} debe ser el default neutro "
                    '"" (es el valor que descarta la cadena, no un valor real)',
                )

    def test_each_geometry_chain_resolves_raw_then_default_then_min_then_max(self) -> None:
        """`GeometryLogic.resolve` recibe (crudo, default, MIN, MAX), en ese orden.

        El rol de cada posición importa: intercambiar MIN y MAX no rompe ningún
        nombre, pero pinea el valor contra el piso (o el techo) sin que nada lo
        delate.
        """
        geometry = self.read_required(GEOMETRY_QML)
        calls = top_level_arguments(geometry, "GeometryLogic.resolve")
        self.assertEqual(
            len(calls), 3,
            "Geometry.qml debe resolver exactamente 3 valores con GeometryLogic.resolve, "
            f"pero se encontraron {len(calls)}",
        )
        for env_name, _setting, default, minimum, maximum in GEOMETRY_CHAINS:
            with self.subTest(env=env_name):
                matching = [
                    args for args in calls
                    if len(args) == 4 and env_name in canonical(args[0])
                ]
                self.assertEqual(
                    len(matching), 1,
                    f"GeometryLogic.resolve de {env_name} debe recibir como primer argumento la "
                    f"expresión cruda que contiene {env_name} (hoy ninguna llamada de 4 argumentos la nombra)",
                )
                args = [canonical(arg) for arg in matching[0]]
                self.assertIn(
                    env_name, args[0],
                    f"El primer argumento de GeometryLogic.resolve de {env_name} es el valor crudo "
                    f"(la expresión con {env_name}), no el default ni una cota",
                )
                self.assertEqual(
                    args[1], default,
                    f"El segundo argumento de GeometryLogic.resolve de {env_name} debe ser el default "
                    f"{default} (orden del contrato: crudo, default, MIN, MAX)",
                )
                self.assertEqual(
                    args[2], f"GeometryLogic.{minimum}",
                    f"El tercer argumento de GeometryLogic.resolve de {env_name} debe ser el piso "
                    f"GeometryLogic.{minimum} (un MIN y un MAX intercambiados pinean el valor al extremo)",
                )
                self.assertEqual(
                    args[3], f"GeometryLogic.{maximum}",
                    f"El cuarto argumento de GeometryLogic.resolve de {env_name} debe ser el techo "
                    f"GeometryLogic.{maximum} (el MAX va último en la lista de argumentos)",
                )

    def test_theme_settings_properties_read_their_exact_shell_json_keys(self) -> None:
        """Cada propiedad `settings*` lee la clave de shell.json que dice su nombre.

        Sin este contrato, `settingsBarHeight` puede leer `barMarginTop` y el
        valor sigue siendo un entero plausible: el archivo declara las claves y
        las propiedades existen, pero quedan desacopladas. La tabla también
        exige que dos propiedades no compartan la misma clave.
        """
        theme_source = self.read_required(THEME_QML)
        settings = json.loads(self.read_required(SHELL_JSON))
        declared = set(re.findall(
            r"readonly\s+property\s+string\s+(settings\w+)\b", theme_source))
        self.assertEqual(
            declared, set(THEME_SETTINGS_KEYS),
            "Toda propiedad settings* de Theme.qml debe tener su contrato de clave en este test",
        )
        keys = []
        for name, (accessor, key) in sorted(THEME_SETTINGS_KEYS.items()):
            with self.subTest(property=name):
                match = re.search(
                    rf'readonly\s+property\s+string\s+{name}\s*:\s*'
                    rf'{re.escape(accessor)}\(\s*"([^"]*)"\s*\)',
                    theme_source,
                )
                self.assertIsNotNone(
                    match,
                    f"Theme.qml debe declarar `readonly property string {name}: "
                    f'{accessor}("{key}")`, pero hoy no matchea esa lectura',
                )
                self.assertEqual(
                    match.group(1), key,
                    f'{name} debe leer la clave shell.json "{key}", no "{match.group(1)}" '
                    "(la clave desacoplada deja la propiedad con el valor de otra)",
                )
                self.assertIn(
                    key, settings,
                    f'shell.json debe declarar la clave "{key}" que lee {name}',
                )
                keys.append(key)
        self.assertEqual(
            len(keys), len(set(keys)),
            "Dos propiedades settings* no pueden leer la misma clave de shell.json "
            "(la geometría leería el valor de otro valor)",
        )

    def test_theme_num_setting_helper_reads_and_stringifies(self) -> None:
        """`_numSetting` lee el número de Settings y lo pasa a string, o "".

        El helper concentra cuatro claves (workspacesPerMonitor, barHeight,
        barMarginTop y barMarginSide), así que devolver "" sin leer nada apaga los
        cuatro settings de una sola vez. El cuerpo queda pineado entero: la lectura
        `Settings.num(key, undefined)`, la guarda `typeof n === "number"` y el
        `String(n)` que entrega el string no vacío que `pick()` acepta.
        """
        theme_source = self.read_required(THEME_QML)
        bodies = braced_blocks(theme_source, r"function\s+_numSetting\s*\(\s*key\s*\)\s*\{")
        self.assertEqual(
            len(bodies), 1,
            "Theme.qml debe declarar una única función _numSetting(key) con cuerpo, "
            f"pero se encontraron {len(bodies)}",
        )
        statements = [line.strip() for line in bodies[0].splitlines() if line.strip()]
        expected = [
            "const n = Settings.num(key, undefined);",
            'return typeof n === "number" ? String(n) : "";',
        ]
        self.assertEqual(
            statements, expected,
            "_numSetting debe leer Settings.num(key, undefined) y devolver String(n) solo "
            'cuando `typeof n === "number"` (si no, ""): cualquier otro cuerpo deja los cuatro '
            "settings numéricos sin efecto o con un valor inventado",
        )

    def test_bar_margins_bind_each_edge_to_its_geometry_role(self) -> None:
        """Cada borde del bloque `margins` recibe el valor de geometría que le toca.

        El contrato por dígitos y el que busca identificadores aceptan los dos
        bindings intercambiados (arriba con el margen lateral y los costados con
        el superior): solo el rol de cada borde dice cuál es cuál.
        """
        bar = self.read_required(BAR_QML)
        blocks = braced_blocks(bar, r"\bmargins\s*\{")
        self.assertEqual(
            len(blocks), 1,
            f"Bar.qml debe declarar un único bloque margins, pero se encontraron {len(blocks)}",
        )
        bindings = []
        for line in blocks[0].splitlines():
            stripped = line.strip()
            if not stripped:
                continue
            match = re.fullmatch(r"([A-Za-z_]\w*)\s*:\s*(.+)", stripped)
            self.assertIsNotNone(
                match,
                "El bloque margins solo puede contener bindings simples `borde: valor`, "
                f"pero contiene: {stripped!r}",
            )
            bindings.append((match.group(1), match.group(2).strip()))
        self.assertEqual(
            [edge for edge, _value in bindings], ["top", "left", "right"],
            "El bloque margins debe bindear top, left y right (y nada más): un borde de más "
            f"esconde un valor sin rol declarado. Hoy declara {bindings}",
        )
        expected = {
            "top": ("Geometry.barMarginTop",
                    "el margen superior es el que separa del borde de arriba"),
            "left": ("Geometry.barMarginSide",
                     "el margen izquierdo es el lateral (compartido con el derecho)"),
            "right": ("Geometry.barMarginSide",
                      "el margen derecho es el lateral (compartido con el izquierdo)"),
        }
        for edge, value in bindings:
            with self.subTest(edge=edge):
                want, reason = expected[edge]
                self.assertEqual(
                    value, want,
                    f"El binding {edge} debe ser {want}: {reason}; hoy es {value} "
                    "(con top y left/right intercambiados la barra queda pegada al borde equivocado)",
                )

    def test_qml_geometry_suite_header_documents_the_ci_invocation(self) -> None:
        """El header del suite QML documenta el comando que CI realmente corre.

        Documentar `-input tests/geometry` manda al que depura por otro camino
        (el runner con el glob real es el que aplica CI).
        """
        source = self.read_required(QML_GEOMETRY_TEST)
        header = source.split("TestCase", 1)[0]
        self.assertIn(
            "qmltestrunner -input tests/geometry/tst_geometry_logic.qml",
            header,
            "El header de tst_geometry_logic.qml debe documentar el comando exacto que corre CI: "
            "qmltestrunner -input tests/geometry/tst_geometry_logic.qml",
        )
        self.assertNotRegex(
            header,
            r"-input tests/geometry(?![/\w])",
            "El header no puede documentar la forma por directorio (-input tests/geometry): "
            "CI corre el archivo, y un comando documentado distinto desvía a quien depura",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)

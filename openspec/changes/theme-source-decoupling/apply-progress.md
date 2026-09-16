# Apply progress: theme-source-decoupling

Registro de la implementación de este change. Los artefactos y comentarios están en español
(neutro, profesional), siguiendo `openspec/config.yaml`. Sin commits: todo queda en el working tree.

## Estado

Implementación del código y de los contratos de test: **completa y en verde**. Las verificaciones
que requieren una sesión Quickshell en vivo quedan **deliberadamente pendientes** como verificación
manual (no se tocó el desktop activo ni se recargó la shell).

## Cambios por archivo

- `Services/Theme.qml`
  - Cadena de resolución de D3 para `themesRoot`: `SHELL_THEMES_ROOT` → `MOONARCH_THEMES_ROOT` →
    setting `themesRoot` de `shell.json` → default `$HOME/.local/share/moonarch/themes`,
    mediante el helper `Theme.pick()` (primer valor definido y no vacío gana).
  - Nuevo `FileView` propio que lee `<Quickshell.configDir>/shell.json` (`watchChanges: true`)
    y expone los valores crudos como `settingsThemesRoot` y `settingsThemeCommand`.
  - Nuevo default `defaultThemeCommand` (`$HOME/.local/bin/moonarch/theme-selector`) para que
    el literal no viva en `Launcher.qml`.
  - `reloadTheme()` ahora recarga también `overrideView` (D6).
  - Agrupación de aplicaciones de paleta con `Qt.callLater` (tarea 3.2): los tres `FileView`
    solo actualizan caches y piden una aplicación convergente.
  - Comentario de cabecera reescrito (tarea 1.4): la raíz de temas es configurable con moonarch
    como default, no como requisito; `quickshell.json` documentado como opcional con prioridad total.
- `Modules/Launcher/Launcher.qml`
  - `themeSelector` deja de ser un literal y se resuelve con la cadena de D3
    (`SHELL_THEME_COMMAND` → `MOONARCH_THEME_COMMAND` → `Theme.settingsThemeCommand` →
    `Theme.defaultThemeCommand`).
  - Degradación D4: sonda `FileView` sobre el comando resuelto (`themeCommandAvailable`);
    si el comando está vacío o no existe, el modo Themes lista los directorios de la raíz con
    `find` y conserva el mensaje "Listing themes read-only: applying requires a theme provider".
  - `accept()` no intenta aplicar en modo lectura; el watchdog del listado degrada al modo
    lectura si la sonda confirma que el comando no existe.
- `shell.json` (nuevo): settings de la shell; los dos valores en `null` significan "usar el
  default". En runtime el symlink `~/.config/quickshell/selene` lo monta como
  `~/.config/quickshell/selene/shell.json`.
- `tests/test_selene_corrections.py`: cuatro contratos nuevos (ver abajo) y la actualización del
  contrato preexistente del `exec` de `--list` (ahora el argv se elige por disponibilidad).

## Desviaciones respecto de `design.md`

Anotadas en `design.md` bajo "Desviaciones registradas durante la implementación":

1. **D2**: Quickshell 0.3.1 no soporta settings custom en `QuickshellSettings` (solo
   `workingDirectory` y `watchFiles`); el archivo `shell.json` se lee del lado de Selene con
   `FileView`, en la misma ubicación prevista por D2.
2. **D3**: el alias `MOONARCH_THEME_COMMAND` se implementa como está escrito, pero no protege
   ninguna configuración existente: esa variable nunca existió en este código (el comando estaba
   hardcodeado). `MOONARCH_THEMES_ROOT` sí existía y sigue funcionando.
3. **D3.2 (tarea 3.2)**: decisión de agrupación con `Qt.callLater`, sin debounce.

## TDD: RED → GREEN por contrato nuevo

Suite: `tests/test_selene_corrections.py` (unittest, stdlib). Contratos agregados:

1. `test_theme_command_resolution_is_configurable_not_hardcoded` (tarea 4.1)
   - RED: falló porque `themeSelector` seguía siendo
     `Quickshell.env("HOME") + "/.local/bin/moonarch/theme-selector"` y no existían
     `SHELL_THEME_COMMAND` / `MOONARCH_THEME_COMMAND` / `Theme.settingsThemeCommand`.
   - GREEN: pasa con la cadena de resolución implementada.
2. `test_themes_root_resolution_is_neutral_first_with_moonarch_alias` (tareas 1.2/1.3, raíz)
   - RED: falló porque no existía `SHELL_THEMES_ROOT` ni `settingsThemesRoot` ni `shell.json`.
   - GREEN: pasa con la cadena neutro-primero, alias y default conservado.
3. `test_theme_mode_degrades_to_readonly_listing_without_provider` (tarea 4.2)
   - RED: falló porque no existían `themeCommandAvailable` ni `themeListReadOnly` ni el mensaje
     de proveedor.
   - GREEN: pasa con la sonda `FileView`, el modo lectura y el guard de `accept()`.
4. `test_reload_theme_reloads_all_three_theme_file_views` (tarea 4.3, regresión de D6)
   - RED: falló porque `reloadTheme()` solo recargaba `ghosttyView` y `waybarView`.
   - GREEN: pasa con `overrideView.reload()` agregado.

Salida RED observada: `Ran 37 tests ... FAILED (failures=4)` (los 33 preexistentes en verde).
Salida GREEN observada: `Ran 37 tests ... OK`.

Ajuste a un contrato preexistente: `test_launcher_exposes_migrated_modes_and_safe_processes`
verificaba el literal `[themeSelector, "--list"]`; ahora verifica
`root.themeSelector, "--list"]` y la presencia del argv de `find`, porque el exec elige el
argv según la disponibilidad del comando. El comportamiento `--apply` no cambió.

## Validación ejecutada

- `python3 tests/test_selene_corrections.py`: OK (37 tests, incluye los 4 nuevos).
- `python3 tests/test_battery_contracts.py`: OK (6 tests).
- `python3 tests/test_media_contracts.py`: OK (6 tests).
- `python3 tests/test_overlay_foundation.py`: OK (4 tests).
- `grep -n "theme-selector" Modules/Launcher/Launcher.qml`: sin resultados (exit 1) — tarea 2.1.
- `qs -V` y lectura de `/usr/lib/qt6/qml/Quickshell/quickshell-core.qmltypes`: base de la
  verificación de la tarea 1.1.
- Nota de sustitución: la tarea 4.4 prescribe `python3 -m pytest tests/ -q`, pero `pytest` no
  está instalado en este entorno; se corrieron los cuatro archivos de la suite por separado.
- `qmllint` sobre `Services/Theme.qml`: exit 0 (solo warnings preexistentes del proyecto).
  `qmllint` sobre `Launcher.qml` reporta duplicate-ids preexistentes (tres `Process` hermanos
  comparten ids); la suite del repo solo lintea `Moon.qml`, y no es una regresión de este change.

## Tareas pendientes y por qué

- **1.3** (mitad de verificación en runtime): arrancar la shell y verificar la cadena con env
  exportadas. Requiere sesión en vivo.
- **2.2 / 2.3** (verificación en vivo): abrir el modo Themes contra un comando inexistente y
  contra el proveedor real. Requiere sesión en vivo.
- **3.1** (mitad de verificación en runtime): `themeReload` con `quickshell.json` presente.
  Requiere sesión en vivo.
- **5.1–5.4**: verificación end-to-end de arranque, defaults y override. Requiere sesión en vivo.
- **6.1**: archivar el change requiere editar `openspec/specs/theme-system/spec.md`, fuera de
  las superficies autorizadas de esta implementación.
- **6.2**: `ROADMAP.md` está fuera de las superficies autorizadas.
- **6.3**: bump del pin del submódulo, atado a la publicación.

## Correcciones acotadas de verificación

Tres correcciones dirigidas por verificación sobre el change:

1. `tests/test_selene_corrections.py` — `test_theme_mode_degrades_to_readonly_listing_without_provider`
   ahora ancla el **orden** del ternario del `exec` del listado (`themeListReadOnly ? [find,
   root.themesRoot, ...] : [root.themeSelector, "--list"]`): antes cada argv se asserteaba por
   separado, así que un ternario invertido habría pasado. Prueba de mutación desechable con
   `python3 -c` (sin tocar código de producción): el orden real pasa y el ternario invertido falla.
   Además se agrega una aserción no vacua sobre `themesLoading`: `themeListExited` debe limpiar
   `themesLoading = false` antes de ramificar por modo lectura (el caso sin proveedor no puede
   quedar cargando); también verificada con prueba de mutación (un guard `if (themeListReadOnly)
   return;` agregado antes del reset hace fallar la aserción).
2. `openspec/changes/theme-source-decoupling/tasks.md` — tarea 3.3 desmarcada y su nota reescrita:
   el análisis estático sostiene el comportamiento con el fragmento ausente, pero la confirmación
   en runtime queda pendiente. Ningún otro checkbox cambió.
3. `.gitignore` — bajo `# Local agent runtime state` se ignora exactamente
   `.pi/gentle-ai/sdd-preflight.json`; el resto de `.pi/` (configuración de proyecto/usuario)
   sigue siendo versionable.

Validación observada: los cuatro archivos de la suite en verde (37 + 6 + 6 + 4 tests).

## Correcciones 5.1 y 5.2 (palette ANSI + Quickshell.shellDir)

1. **Tarea 5.1 — `parseGhostty` ahora parsea el palette ANSI real.** Los 13 bundles de
   `~/.local/share/moonarch/themes/*/ghostty.conf` usan la forma `palette = N=#RRGGBB`; el primer
   split en `=` dejaba key=`palette` y val=`5=#F5C2E7`, así que el regex sobre la clave nunca
   matcheaba y `p0`–`p15` quedaban vacíos (los tokens `success`, `warning`, `purple`, `cyan` y
   `gray` conservaban el fallback Tokyo Night). Fix en `Services/Theme.qml`: rama `key === "palette"`
   que matchea `val` con `/^(\d+)\s*=\s*(.+)$/` y guarda `p0..p15`; la forma legada
   `palette N = #RRGGBB` (regex sobre la clave) se conserva intacta. Ninguna otra derivación,
   prioridad ni fallback cambió.

   Contrato primero (RED): `test_parse_ghostty_supports_real_ghostty_palette_form` agregado a
   `tests/test_selene_corrections.py` y verificado que FALLA contra el parser previo
   (`Regex didn't match: 'val\\.match...' not found`), junto con
   `test_settings_file_view_uses_shelldir_not_configdir` también en rojo. Límite del contrato
   declarado en su docstring: es estructural, no prueba runtime; la prueba de runtime es el probe.

   **Evidencia de runtime (probe aislado, `/tmp/tsd-probe` con `Services/Theme.qml` symlinked al
   archivo de producción, `SHELL_THEMES_ROOT=/tmp/tsd-themes-real` → `catppuccin-mocha`):**
   - Antes del fix: `PROBE|t=6s|root=/tmp/tsd-themes-real|bg=#11111b|accent=#a6adc8|purple=#bb9af7`
     (`#bb9af7` = fallback Tokyo Night).
   - Después del fix: `PROBE|t=6s|root=/tmp/tsd-themes-real|bg=#11111b|accent=#a6adc8|purple=#F5C2E7`
     (`#F5C2E7` = valor real del bundle, línea `palette = 5=#F5C2E7`).

2. **Tarea 5.2 — `Quickshell.configDir` reemplazado por `Quickshell.shellDir`.** El `FileView` de
   settings (`Services/Theme.qml`) sigue leyendo `shell.json` de la misma ubicación; sin cambios de
   semántica. La referencia en el comentario de encabezado también se actualizó. Sin warning de
   deprecación en la salida del probe (grep sobre la corrida completa: sin `configDir`/`deprecat`).

Validación observada: los cuatro archivos de la suite en verde (39 + 6 + 6 + 4 tests).

## Guardia estructural contra referencias `root.<name>` no declaradas (bug D4)

3. **Bug en la degradación D4 — `root.themesRoot` no declarado en `Launcher.qml`.** La rama de
   listado en modo lectura del ternario de `loadThemes()` usaba `root.themesRoot`, pero esa
   propiedad nunca existió en el Launcher: la raíz resuelta vive en el singleton `Theme`
   (`Services/Theme.qml`, `readonly property string themesRoot`, cadena D3). La referencia
   evaluaba a `undefined`, el comando se armaba como `find undefined ...` y fallaba con
   `find: 'undefined': No such file or directory` (exit 1); el Launcher mostraba ese texto de
   stderr en la barra de estado y no listaba nada. Es decir, el caso exacto que la degradación
   D4 existe para soportar (sin proveedor disponible) era el roto. Fix: la rama verdadera del
   ternario usa `Theme.themesRoot`. La cadena D3, `shell.json` y la rama del proveedor quedaron
   intactas.

   Guardia nuevo (`test_launcher_root_references_resolve_to_declared_or_base_properties`):
   colecciona cada referencia `root.<name>` del archivo, cada propiedad/función declarada, y
   exige que las referencias usadas pero no declaradas estén en una allowlist minimal de
   propiedades heredadas del tipo base (hoy solo `visible`). Contrato primero (RED): falló
   contra el código previo señalando exactamente `['themesRoot']`; tras el fix quedó en verde
   con el conjunto restante `['visible']` (58 nombres declarados, medida confirmada). Las dos
   aserciones que anclaban el string del bug (`'"find", root.themesRoot'` en dos tests) ahora
   anclan `'"find", Theme.themesRoot'`: un test que fija el texto de un bug es peor que no
   tener test.

Validación observada: los cuatro archivos de la suite en verde (40 + 6 + 6 + 4 tests).

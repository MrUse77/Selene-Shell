# Tasks: declarar la geometría de la barra (Selene#8, primera mitad)

## Goal

Que la altura y los márgenes de la barra dejen de ser literales calibrados para
la máquina del autor y pasen a resolverse por la cadena `env neutra → shell.json →
default`, sin cambiar un píxel del layout actual cuando no hay configuración.

Issue: `MrUse77/Selene-Shell#8` — *Declarar la geometría y los márgenes (dejar de
asumir el layout)*.

## Context

- Repo: `MrUse77/Selene-Shell`. Worktree `/home/agustin/Dev/Lab/QML-worktrees/panel-geometry`,
  rama `feat/panel-geometry` creada desde `main` (`007742d`, ya igual a `origin/main`).
- Inventario de literales (read-only, 2026-09-20, `HEAD=007742d`):
  - `Modules/Bar/Bar.qml:22-23` `margins { top: 10; left: 14; right: 14 }`;
    `:26` `implicitHeight: 44`; `:27` `exclusiveZone: 44` (duplica el 44).
  - Offsets de overlays escritos como literales sueltos, derivados de `10 + 44 + gap`:
    `Modules/Dashboard/Dashboard.qml:29` `top: 56` (+2),
    `Modules/Bar/CalendarPopup.qml:29` `top: 58` (+4),
    `Modules/Bar/HistoryPopup.qml:27` `top: 58` (+4),
    `Modules/Notifications/Notifications.qml:31` `top: 60` (+6).
  - `Modules/Osd/Osd.qml:17` `margins.bottom: 90` — independiente de la barra.
  - **Nadie lee la altura de barra**: no hay referencia a `Bar.height`, no hay
    constante compartida y `Bar.qml` no exporta id. Los cuatro `top:` de arriba son
    la única "cadena", y es por copia.
- Cadena ya existente en el repo (a copiar, no a inventar): `Services/Theme.qml:36-42`
  `pick()` = primer argumento string no vacío, último argumento = default; `Theme.qml:65-70`
  la usa como `Quickshell.env("SHELL_*") → Theme.settingsX → default`. Consumidores con
  la cadena completa: `Modules/Bar/Workspaces.qml:22-34` (env → setting → default con
  validación y clamp), `Services/Hardware.qml:29-35`, `Modules/Launcher/Launcher.qml:42-47`.
- Restricciones de contrato vigentes en `tests/test_selene_corrections.py`:
  - `:736` todo `Theme.settingsX` referenciado fuera de `Theme.qml` debe estar
    declarado con `readonly property string settingsX` → los settings numéricos
    viajan **como string** (así lo hace `settingsWorkspacesPerMonitor`, `Theme.qml:57-60`).
  - `:687` sólo `Services/Settings.qml` puede apuntar una lectura a `shell.json`.
- Testeo: los tests QML nunca importan singletons, sólo `Services/*Logic.js` puros
  (`tests/overlay-state/tst_overlay_state.qml:4-7` importa cuatro `.js`). Los contratos
  de fuente (literales ausentes, orden de la cadena, claves de `shell.json`) viven en
  `tests/test_*.py`. CI (`.github/workflows/ci.yml`) corre `python3 -m unittest discover`,
  `qmltestrunner` sobre `tests/*/tst_*.qml` (globo, sin tocar el workflow) y
  `qmllint --missing-property error` sobre todos los `.qml`/`.js`.
- Herramientas locales presentes: `/usr/bin/qs` (+`quickshell`), `/usr/bin/qmltestrunner`,
  `/usr/bin/qmllint`, `/usr/bin/grim`, `/usr/bin/magick`, `/usr/bin/compare`, `hyprctl`.
  `actionlint` no está instalado localmente (este cambio no toca workflows).
- Realidad del runtime vivo: `qs -c selene` (PID 1908) corre sobre
  `~/.config/quickshell/selene`, que **no es un symlink** sino un checkout propio en
  `feat/media-keys-ipc` (4 divergencias contra el worktree, todas en docs/tests de
  media). `openspec/config.yaml` afirma que ese path es un symlink al repo: **es falso**
  y hay que corregirlo o registrarlo. Las líneas de geometría de esa copia son idénticas
  a `HEAD`.
- TDD: no hay modo TDD configurado en `openspec/config.yaml` ni en `.pi/`. Los checks
  son los tres gates del CI, corridos localmente. La disciplina igual es rojo primero
  donde hay contrato que pueda fallar.

## Decisions

- **Alcance partido (decisión del usuario, 2026-09-20).** Esta rama entrega la
  **barra**: servicio de geometría, cadena de resolución y `Bar.qml`. Los overlays
  (OSD, Dashboard, Calendar, History, Notifications) son la segunda mitad y van en
  rama aparte, consumiendo el servicio que queda acá.
- **Valores declarables:** `barHeight` (44), `barMarginTop` (10) y `barMarginSide`
  (14). Los offsets de los popups **no** se declaran: se derivan en la segunda mitad
  como `margen + altura de barra + gap de diseño`, y esos gaps (2/4/6) quedan como
  constantes de diseño, no como settings.
- **Nombres:** claves camelCase en `shell.json`, env `SHELL_*` neutras derivadas de la
  clave, sin alias `MOONARCH_*` (esta geometría nunca fue de moonarch, a diferencia de
  los temas):
  - `barHeight` ← `SHELL_BAR_HEIGHT`
  - `barMarginTop` ← `SHELL_BAR_MARGIN_TOP`
  - `barMarginSide` ← `SHELL_BAR_MARGIN_SIDE`
- **La lógica de resolución es pura y vive en `Services/GeometryLogic.js`**, testeable
  con `qmltestrunner` sin singletons, según el patrón de `BatteryLogic.js`/`OverlayState.js`.
- **Los defaults viven en el servicio**, no en cada consumidor: hay un solo lugar que
  sabe que la barra mide 44 y que el margen superior es 10. Precedente:
  `Theme.defaultThemeCommand` (`Theme.qml:73-74`).
- **Rango válido de `barHeight`: 34..96.** 34 es el elemento interno más alto
  (`Modules/Bar/Workspaces.qml:15` `implicitHeight: 34`); por debajo la barra recorta
  contenido fijo. Un entero válido fuera de rango se acota (precedente del clamp de
  `Workspaces.qml`); un valor no entero o no numérico cae al default.
- **`exclusiveZone` se deriva de la altura resuelta** (`exclusiveZone: implicitHeight`):
  hoy duplica el `44` en la línea siguiente y es exactamente el tipo de copia que este
  issue viene a eliminar. No se declara como setting propio: la zona exclusiva es
  "la altura de la barra", no un valor independiente.
- **Validación visual por máscara (decisión del usuario, 2026-09-20).** Sin detener la
  shell viva: `qs -p <worktree>` levanta una segunda instancia con la geometría por
  default sobre la barra desplegada, y `grim` captura el monitor antes/después. Si la
  geometría coincide, la diferencia entre "shell sola" y "shell + probe" se concentra
  exactamente en el rectángulo del panel (más el halo de `Components/Capsule.qml:19-24`,
  +6 px); si algo se corrió, aparecen flecos fuera de ese rectángulo.

## Non-goals

- Tocar `Modules/Osd/Osd.qml`, `Modules/Dashboard/Dashboard.qml`,
  `Modules/Bar/CalendarPopup.qml`, `Modules/Bar/HistoryPopup.qml`,
  `Modules/Notifications/Notifications.qml`: es la segunda mitad, en rama aparte.
- Declarar como settings los offsets internos de diseño (insets de 6 px, hitboxes
  42×32/40×32, ancho de popups 320/380, gaps de 2/4/6).
- Detener, reiniciar o redeployar `qs -c selene` (PID 1908). El probe se limpia solo.
- Corregir el `openspec/config.yaml` que miente sobre el symlink del deploy: se
  registra como hallazgo y follow-up, no se arregla acá.
- Instalar `actionlint` ni tocar `.github/workflows/ci.yml`.

## Tasks

- [x] **T1 — Instrumento y contratos primero (rojo).** Baseline medido con el
      compositor, no sólo con píxeles: `hyprctl layers -j` da enteros exactos por
      monitor. Estado previo (2026-09-20 11:50): barra desplegada PID 1908
      `DP-2 14,10 1892x44` y `HDMI-A-1 1934,10 1892x44`; superficie de notificaciones
      `HDMI-A-1 lvl3 3442,60 380x1`.
      **Hallazgo que cambió el método:** Hyprland apila zonas exclusivas, así que el
      probe **no** cae en `y=10` sino en `y=64` (`= 10 + 44 + 10`), con el mismo
      `w x h` que la barra viva. Un diff global contra "la shell sola" medía ese
      desplazamiento apilado, no la geometría. Y el escritorio está vivo: dos capturas
      de la misma shell separadas por minutos difieren en 371.800 px por ventanas
      movidas, así que el diff global quedó descartado como instrumento. Piso de ruido
      medido con la shell sola: 82 px en un solo widget (x 1795-1803, y 25-36), y
      **0 px fuera del rectángulo de la barra**.
      Rojo observado por el implementador, dos fases: en la fase del servicio,
      `required geometry file is missing: .../Services/Geometry.qml` y
      `qmltestrunner::tst_geometry_logic::compile() Script file:///.../GeometryLogic.js
      unavailable` → `Totals: 0 passed, 1 failed`; en la fase de la barra,
      `'implicitHeight: 44' unexpectedly found in ...` y `'Geometry.barMarginTop' not
      found in '\n        top: 10\n        left: 14\n        right: 14'`. El
      verificador independiente no puede probar el *orden temporal* (no hay artefacto
      que lo registre) pero sí la no-vacuidad: con los tests nuevos sobre el árbol
      prístino, fallan los 11 contratos y la suite QML no compila.

- [x] **T2 — Servicio de geometría (verde).** `Services/GeometryLogic.js`,
      `Services/Geometry.qml`, `Services/qmldir`, proyección de settings en
      `Services/Theme.qml` (helper `_numSetting` compartido) y `shell.json` con las
      tres claves en `null`.
      Evidencia de gates: python `Ran 81 tests / OK` (baseline 64; +11 contratos de
      geometría y +6 de rol de argumentos); `qmltestrunner` 4 suites
      (16 / 8 / 11 / 41 pasados, 0 fallados; baseline 3 suites); `qmllint
      --missing-property error` 49 archivos, exit 0, 0 errores y **57 ocurrencias de
      `Warning:` idénticas al árbol prístino** (46 archivos). Corrección: el conteo
      48 del primer reporte medía líneas que empiezan con `Warning:`, y qmllint pega
      un aviso al final de una línea de `Info:` — el conteo por ocurrencias es 57/57.
      Evidencia de cadena viva (`qs -p` + `hyprctl layers`, 8 casos, shell viva intacta,
      0 errores en el log del probe, sin instancias residuales):

      | caso | superficie del probe (DP-2) | conclusión |
      | --- | --- | --- |
      | default, sin env ni setting | `14,64 1892x44` | el default reproduce el layout previo |
      | `SHELL_BAR_HEIGHT=60` | `14,64 1892x60` | la env gana |
      | `shell.json` `barHeight=55` | `14,64 1892x55` | el setting también se lee |
      | env 60 + setting 55 | `14,64 1892x60` | la env precede al setting |
      | `SHELL_BAR_HEIGHT=10` | `14,64 1892x34` | el piso de 34 acota, no cae al default |
      | `SHELL_BAR_HEIGHT=abc` | `14,64 1892x44` | basura cae al default |
      | `SHELL_BAR_MARGIN_TOP=30` | `14,84 1892x44` | `84 = 54 + 30`: el margen se aplica |
      | `SHELL_BAR_MARGIN_SIDE=30` | `30,64 1860x44` | `1860 = 1920 - 2x30`: el margen lateral también |

- [x] **T3 — La barra consume el servicio.** `Modules/Bar/Bar.qml`: `margins`
      bindeados a `Geometry.barMarginTop` / `Geometry.barMarginSide`,
      `implicitHeight: Geometry.barHeight`, `exclusiveZone: implicitHeight` con
      comentario. Nada más de ese archivo cambió (insets de 6 px, hitboxes 42x32 y
      40x32, `Divider` 10/32/1/16 y `radius: height / 2` quedaron byte a byte iguales).
      Contratos: `test_bar_margins_bind_each_edge_to_its_geometry_role` y
      `test_bar_height_and_exclusive_zone_come_from_geometry`.
      Evidencia: la superficie del probe con default es `1892x44`, idéntica a la de la
      barra desplegada pre-cambio, y la mutación de invertir `top`/`left-right` falla
      con `'Geometry.barMarginSide' != 'Geometry.barMarginTop'`.

- [x] **T4 — Verificación visual A/B contra el estado previo.** El plan original
      (máscara idéntica contra la captura previa) quedó invalidado por dos hechos
      medidos: el apilado de zonas exclusivas y el ruido ambiente del escritorio vivo.
      Método aplicado: por cada captura se mide la **banda de la cápsula** por firma de
      color (el relleno `Theme.bg` al 88% es una banda oscura y uniforme de 1892 px de
      ancho), lo que es geométrico e inmune al fondo.
      Evidencia (DP-2, filas inclusivas):

      | captura | banda de la cápsula | filas de borde (mediana RGB) | centro del contenido |
      | --- | --- | --- | --- |
      | pre-cambio (literales) | `64..107` | 64 y 107 = (20,26,40) | y≈86,5 |
      | post-cambio default | `64..107` | 64 y 107 = (20,26,40) | y≈86,5 |
      | post-cambio `SHELL_BAR_HEIGHT=60` | `64..123` | 64 y 123 = (20,26,40) | y≈93,5 |

      Lectura: la cápsula renderizada ocupa exactamente las mismas filas antes y después
      del cambio (44 de alto), y con la env en 60 mide 60 filas (64..123) con el mismo
      color de borde. El contenido interno se recentra (86,5 → 93,5 = +8 = la mitad de
      los 16 px agregados): la barra no queda con el contenido pegado arriba. El
      outlier de 128 filas que apareció con detección por gradiente en una sola captura
      era el borde de una ventana del fondo, no la cápsula; la firma de color lo
      desambigua. Al terminar: 0 instancias del probe y PID 1908 vivo (uptime intacto).

- [x] **T5 — Roadmap, y spec canónico fuera de alcance (decisión).** `ROADMAP.md`
      registra que #8 quedó partido, qué entrega la barra (claves y cadena) y qué
      queda pendiente (overlays y popups encadenados a la altura de barra).
      **`openspec/specs/bar/spec.md` no se toca.** Precedente de la casa: el cambio
      de teclas de media documenta el contrato en su doc de ODD y deja el spec formal
      "a un `changes/` propio si el equipo lo quiere"; `openspec/config.yaml` declara
      `schema: spec-driven`, y esta rama no es un change de OpenSpec. Además el spec
      canónico de bar ya está desactualizado por su cuenta: afirma "5 por monitor"
      fijo (lo refuta el cambio de `workspacesPerMonitor`) y que los overlays flotan
      "SIN zona exclusiva" (la barra es la única superficie con zona exclusiva, y
      ahora se deriva de su alto). Escribir el requirement sin pasar por el ritual de
      change+sync dejaría el mismo spec viejo con una sección nueva: queda como
      decisión del usuario, registrada en los follow-ups.
      Evidencia: los gates no dependen de docs (ningún test lee `openspec/`, verificado
      con `grep -rn openspec tests/*.py .github/workflows/ci.yml` sin resultados); el
      párrafo nuevo del roadmap reemplaza el "Falta: geometría y márgenes (#8)" y
      sobrevive la corrida completa: python `81 tests / OK`, 4 suites QML 0 fallados,
      `qmllint` exit 0.

## Segunda mitad (rama aparte, no es tarea de acá)

- **TB1** — `panelTop(marginTop, barHeight, gap)` puro en `GeometryLogic.js`, con los
  tres gaps de diseño (2/4/6) y los literales `56/58/60` como caso de test.
- **TB2** — `osdMarginBottom` (90) como cuarta clave declarable; OSD con
  `margins.bottom: Geometry.osdMarginBottom`.
- **TB3** — Dashboard, Calendar, History y Notifications consumiendo el servicio,
  más el margen lateral de popups (`barMarginSide + 4 = 18`) derivado.
- **TB4** — Máscara visual de la segunda mitad: los popups con `SHELL_BAR_HEIGHT=60`
  tienen que seguir el nuevo borde inferior de la barra.

## Follow-ups registrados (no son tareas de este cambio)

- **El requirement formal de la geometría no existe en el spec canónico.** Decisión
  tomada acá: no editar `openspec/specs/bar/spec.md` a mano, porque
  `openspec/config.yaml` declara `schema: spec-driven` y este trabajo no pasó por un
  change. Queda para el usuario decidir si abre un `changes/` con el requirement de
  geometría declarada (texto propuesto en la conversación de esta sesión) o si el
  spec se edita directo.
- **El spec canónico de bar está desactualizado, independiente de este cambio.**
  `openspec/specs/bar/spec.md:18` dice "5 por monitor" fijo, cuando ese valor es
  declarable desde el cambio de `workspacesPerMonitor`; y el *Purpose* afirma que los
  overlays flotan "SIN zona exclusiva", cierto para los overlays pero no para la
  barra, que es la única superficie con zona exclusiva (ahora derivada de su alto).
- **H6 — La cadena viva no está cubierta por CI.** Todo lo que corre en el pipeline son
  contratos de texto sobre el código fuente más la suite QML sobre el `.js` puro; ningún
  test instancia el singleton `Geometry`, `Theme.pick` ni la precedencia real entre env y
  `shell.json`. La única evidencia de runtime de este cambio es la sonda contra el
  compositor, que CI no puede correr (no hay Wayland). Vale un harness de sonda
  versionado si la segunda mitad repite el método.
- **H5 — Un solo helper para cuatro settings.** `Theme._numSetting` concentra
  `workspacesPerMonitor`, `barHeight`, `barMarginTop` y `barMarginSide`: un cuerpo roto
  los anula a los cuatro. El agujero es preexistente (vaciarlo también deja verde al
  árbol prístino) y ahora queda pinneado por contrato de cuerpo
  (`test_theme_num_setting_helper_reads_and_stringifies`), pero sigue sin haber ejecución.
  Se cierra de verdad con H6.
- **H7 — Env con solo espacios le gana al setting.** `Theme.pick` acepta cualquier string
  no vacío, así que `SHELL_BAR_HEIGHT=" "` gana la cadena y después `resolve` lo manda al
  default: el valor de `shell.json` queda ignorado en silencio. Es un rasgo de la casa
  (`workspacesPerMonitor` y `tempSensor` se comportan igual), no una regresión de este
  cambio.
- **H8 — Acotado silencioso.** `SHELL_BAR_HEIGHT=-5` da 34 y `=500` da 96 sin aviso
  visible. El acotado es deliberado y está documentado en el módulo; el aviso al usuario
  pertenece a la UI de estados de configuración (#11).
- **Los scripts de la sonda viven en `/tmp`** (`geom_probe_check.py`, `geom_visual_check.py`,
  `geom_edges.py`, `geom_probe/shell.qml`), fuera del repo: no entran en el commit y CI no
  los corre. Si la segunda mitad repite el método, conviene versionarlos.
- **`openspec/config.yaml` describe un deploy que no existe.** Dice
  "symlink `~/.config/quickshell/selene` -> este repo" y el path real es un checkout
  propio en otra rama. Cualquier validación visual que asuma el symlink mide la copia
  vieja.
- **El deploy vivo está atrás de `main`** (4 divergencias, todas en docs/tests de media).
  No se toca en esta rama: es decisión del usuario.
- **El worktree principal `~/Dev/Lab/QML` quedó parado en `feat/media-keys-ipc`**, una
  rama ya mergeada. Conviene volverlo a `main` o borrarlo, pero es decisión del usuario.

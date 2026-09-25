# Tasks: comandos de herramientas configurables

## Objetivo

Resolver la issue `MrUse77/Selene-Shell#9` (“Comandos de herramientas
configurables”): ningún módulo debe invocar una herramienta externa por un
nombre fijo; cada comando debe pasar por la cadena

`variable de entorno neutral → shell.json → default actual`

y un comando ausente o inválido debe producir una degradación visible en vez
de un clic muerto.

## Problema

Varios módulos todavía construyen argv con literales:

- `Modules/Bar/AudioWidget.qml` → `pavucontrol`
- `Modules/Bar/UpdatesWidget.qml` → `ghostty -e paru`
- `Modules/Launcher/Launcher.qml` → `wl-copy`, `find` y `notify-send`
- `Modules/PowerMenu/PowerMenu.qml` → `hyprlock`, `hyprctl` y `systemctl`
- `Modules/Dashboard/Dashboard.qml` → `bluetoothctl` y `systemctl`

Si la herramienta no existe, algunos clics terminan en silencio. La infraestructura
base ya existe y fue probada: `Services/Settings.qml` (PR #15) y `Theme.pick()`
resuelven settings y defaults; el Launcher ya degrada la lista de temas cuando
el proveedor no existe.

## Por qué

- Es la siguiente issue abierta de mayor valor después de cerrar la geometría.
- La base de settings ya está mergeada y probada; falta conectar los consumidores.
- Cambia fallos silenciosos en feedback accionable sin alterar los defaults.
- No depende de la issue #18 ni de trabajo externo en MoonArch.

## Alcance autorizado

- Repositorio: `MrUse77/Selene-Shell`.
- Rama: `feat/configurable-tool-commands` desde `main` (`cbcc57d`).
- Issue de entrega: `#9`.
- Archivos esperados: `Services/Commands.qml`, lógica pura de parsing/envío si
  hace falta, `Services/qmldir`, `shell.json`, los módulos listados arriba y
  contratos en `tests/`.
- Fuera de alcance: MoonArch, dotfiles, `~/.config`, Quickshell live, OSD nuevo,
  renombre del proveedor de temas y cambios de issue no relacionados.
- La issue no tiene el label `status:approved`; antes de abrir la PR hay que
  confirmar el gate issue-first de este repo o registrar la aprobación explícita
  del maintainer.

## Decisiones

- **Cadena de resolución:** para cada comando, `Quickshell.env("<SHELL_*_COMMAND>")`
  → `Settings.str("<key>")` → default actual. Una cadena vacía o de tipo
  equivocado cae al siguiente nivel, nunca rompe el clic.
- **Default inmutable:** el comportamiento sin env ni setting debe ser idéntico
  al actual (`pavucontrol`, `ghostty -e paru`, `wl-copy`, etc.).
- **Parsing sin shell para valores configurados:** parsear la cadena a argv con
  la lógica existente/una lógica pura equivalente; no interpolar settings en
  `sh -c`. Las rutas con espacios y comillas deben sobrevivir.
- **Degradación visible reutilizando superficies existentes:**
  - Launcher y PowerMenu usan su `statusText`/`errorText` actual.
  - Widgets sin estado inline reutilizan la notificación desktop ya usada por
    Launcher/PowerMenu.
  - No se agrega un sistema de toasts ni un estado global nuevo.
- **Inventario por acceptance, no por ejemplos:** además de los nombres citados
  en la issue, migrar las llamadas fijas alcanzables desde módulos que quedarían
  fuera del criterio (“ningún módulo…”), incluidos `hyprctl`, `bluetoothctl`,
  `find` y el `notify-send` de fallback. No migrar comandos introducidos por el
  usuario en modo Run ni el selector de temas ya configurable.
- **Modo TDD resuelto:** ordinary, no strict. Fuente: no hay instrucción
  `strict_tdd` de sesión/proyecto para este change; la presencia de tests no
  activa TDD. Runner:
  `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v`.
- **RDD:** `on` (decided by global). El candidato de review será el commit de
  unidad de trabajo contra el boundary previo, nunca TODOs.
- **Estrategia de entrega:** `ask-on-risk`; pronóstico inicial 300–400 líneas
  autorizadas. Si el diff real supera 400, preguntar antes del commit entre
  PRs encadenadas o `size:exception`.
- **Ruta de implementación:** delegated direct. El trigger de escritor aplica
  (más de un archivo no trivial). El mapper delegado falló por un defecto del
  runtime del proveedor (`OpenCode free tier`); el inventario read-only se
  completó con CodeGraph/Grep como fallback disclosed.

## Tasks

- [x] **T1 — Inventario y contratos primero.**
      Catalogar todas las llamadas fijas desde `Modules/**/*.qml`, definir los
      keys/env names y agregar contratos que fallen contra `main`: cada key tiene
      default exacto, cadena de resolución completa, parseo a argv y cobertura
      de que ningún módulo usa uno de los literales proibidos sin `Commands`.
      Registrar el rojo observado si se ejecuta en modo test-first; en ordinary
      mode basta con observar el fallo del contrato antes del wiring.
- [x] **T2 — Servicio `Commands` y settings.**
      Crear `Services/Commands.qml` (+ lógica pura si hace falta), registrar el
      singleton en `Services/qmldir`, agregar las claves nuevas a `shell.json`
      como `null` y exponer propiedades de comando resueltas con
      `env → Settings → default`. La lógica de parsing debe aceptar quoting y
      rechazar quoting/escape incompleto sin ejecutar nada.
- [x] **T3 — Migrar consumidores con degradación visible.**
      Reemplazar los literales en AudioWidget, UpdatesWidget, Launcher,
      PowerMenu y Dashboard por `Commands.*`. Preservar argv efectivo y defaults.
      Launcher/PowerMenu deben mostrar el error en su superficie existente; los
      widgets sin status deben notificar el fallo de forma visible. Ninguna
      configuración debe pasar sin parsing por un shell.
- [x] **T4 — Verificación funcional completa.**
      Correr todos los gates del repo y los contratos nuevos:
      1. `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v`
      2. `qmltestrunner` sobre `tests/*/tst_*.qml` con `QT_QPA_PLATFORM=offscreen`
      3. `qmllint --missing-property error` sobre `.qml`/`.js` (excluir `.git`,
         `.atl`, `.zcode`, `.pi`)
      4. `actionlint` sobre `.github/workflows` si está disponible
      5. Verificación estructural de mutación sobre copia en `/tmp`: quitar un
         key/default, cruzar una delegación o reintroducir un literal de módulo
         deben fallar contratos. Runtime live (`qs -p`/teclas/D-Bus) queda N/A
         salvo autorización explícita.
- [x] **T5 — Commit de unidad de trabajo.** AUTORIZADO por el maintainer con
      `size:exception` explícito. Commit local creado como `83a4548` y amendeado
      para registrar este cierre; el SHA final se registra en Engram porque no
      puede auto-referenciarse dentro del propio commit. Mensaje:
      `feat(commands): resolve external tool commands visibly` (sin
      `Co-Authored-By`). Push/PR siguen siendo decisión del usuario bajo política
      ordinaria. El resultado RDD post-freeze se registra fuera de este documento
      para no invalidar el candidato ya congelado.

## Criterios de aceptación de la issue

- [x] Ningún módulo invoca una herramienta por nombre fijo sin pasar por la
      resolución de `Commands` (contratos en `tests/test_commands_contracts.py`).
- [x] El default no cambia el comportamiento actual (mismos defaults
      `pavucontrol`, `ghostty -e paru`, etc.).
- [x] Falta o inválidez de la herramienta produce feedback visible
      (`statusText`/`errorText` en Launcher/PowerMenu; `Commands.notify` en widgets).
- [x] La cadena env → `shell.json` → default funciona para cada key
      (`Commands._resolve` delega en `Theme.pick`, verificado por contrato).
- [x] Los contratos fallan si se reintroduce un literal o se rompe el orden de
      precedencia (mutaciones M2/M3 observadas).
- [x] Ninguna key de settings se interpola en un shell sin parseo
      (`Commands.argv` + `LauncherLogic.parseCommand`; scan de literales).

## Progreso

- [x] Exploración inicial y contraste con issues/PRs.
- [x] Rama creada localmente desde `main` (`cbcc57d`).
- [x] T1 — rojo observado antes del wiring: 4 failures + 3 errors en
      `test_commands_contracts.py` contra el árbol sin `Commands.qml`.
- [x] T2 — `Services/Commands.qml` + singleton en `qmldir` + 9 keys `null`
      en `shell.json`.
- [x] T3 — 5 módulos migrados; Run-mode y selector de temas sin migrar.
- [x] T4 — gates en verde (evidencia abajo); `actionlint` no instalado.
- [x] T5 — `size:exception` aceptado; commit local creado y cierre T5
      amendeado en el mismo work unit.

## Evidencia

- Gate 1 — Python: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover
  -s tests -v` → `Ran 92 tests ... OK` (84 baseline + 8 contratos nuevos).
- Gate 2 — QML: `QT_QPA_PLATFORM=offscreen qmltestrunner` sobre los 4
  `tests/*/tst_*.qml` → `failed=0`.
- Gate 3 — `qmllint --missing-property error` sobre `.qml`/`.js` (excluye
  `.git/.atl/.zcode/.pi`) → `rc=0`, 0 errores (solo warnings de baseline).
- Gate 4 — `actionlint`: no está instalado en este entorno (reportado,
  honestamente unavailable).
- Gate 5 — Mutaciones sobre copia en `/tmp/opencode/selene9-mut`:
  - baseline → OK; M1 (default roto) → `FAILED (failures=1)`;
  - M2 (precedencia cruzada) → `FAILED (failures=1)`;
  - M3 (literal `pavucontrol` reintroducido) → `FAILED (failures=3)`;
  - baseline restaurado → OK.
- Tamaño final autorizado: **582** líneas (538 adiciones + 44 eliminaciones) en
  11 archivos → excede 400. El maintainer aceptó explícitamente `size:exception`
  para un único commit. Pesos principales: este doc, contratos nuevos (155),
  `Services/Commands.qml` (95), contratos existentes (56) y migración de
  módulos.
- Rollback boundary: revertir el commit de T5 elimina exactamente los 11 paths
  de este change; no arrastra trabajo no relacionado.
- Runtime live (`qs -p`/teclas/D-Bus): N/A por autorización (solo local).
- Review RDD / consent: ocurre después del freeze del candidato; su resultado se
  registra en Engram bajo `odd/configurable-tool-commands/review`, no acá, para
  no invalidar el receipt con una edición posterior.

## Rationale

El trabajo es sustancial pero bien acotado: una superficie de resolución nueva
más la migración de consumidores. Se crea este documento antes del primer source
write para que el scope, los defaults y la degradación visible no se decidan
tácitamente dentro del diff.
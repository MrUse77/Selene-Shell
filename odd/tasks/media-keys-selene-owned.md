# Tasks: teclas de media propiedad de Selene

## Goal

Que las teclas de transporte (`XF86AudioPlay`, `XF86AudioPause`, `XF86AudioNext`,
`XF86AudioPrev`) dejen de depender de un binario externo ausente y pasen a ser
consumidas por Selene, que ya resuelve la selección MPRIS y sus guardas de
capacidad.

## Context

- Repo en trabajo: `MrUse77/Selene-Shell`, worktree `/home/agustin/Dev/Lab/QML`,
  rama `feat/media-keys-ipc` creada desde `main` (`0e5e18e`).
- Deployment vivo: `~/.config/quickshell/selene` es una **copia** (no symlink, no
  git) y **está más atrás que `main`**, no solo sin `theme-source-decoupling`:
  `diff -rq` contra `git archive main` da 20 divergencias, le falta
  `Services/Settings.qml` y su `qmldir` no declara `Settings`, así que predata
  `0e5e18e`. Proceso corriendo: `qs -c selene`, PID 1931, arrancado 2026-09-19 12:16.
- Ruta de MoonArch: el repo es `~/Dev/dotfiles` (tiene `.git`, `home/`, `cli/`).
  `dotfiles/MoonArch` es un symlink a Obsidian y **no** es el repo. Los binds están
  en `home/.config/hypr/hyprland.lua:465-469`; ninguna de las 13 copias de tema
  bajo `home/.local/share/moonarch/themes/*/hyprland.lua` menciona `playerctl`.
- Diagnóstico (read-only, 2026-09-19): los cuatro binds de transporte ejecutan
  `playerctl`, que **no está instalado** en la máquina. `hyprctl binds` registra
  los 10 binds XF86 con `dispatcher: __lua` y `hyprctl configerrors` está vacío,
  así que no es una falla de carga de configuración. Volumen y brillo usan
  `wpctl`/`brightnessctl`, ambos presentes, y no están afectados.
- Superficie ya existente y sin uso desde el teclado: `Services/Media.qml` expone
  `togglePlaying()`, `previous()`, `next()`, `selectPlayer()`, con guardas
  `canTogglePlaying`/`canGoPrevious`/`canGoNext`. `Services/MediaLogic.js`
  resuelve el jugador por prioridad (`isPlaying` → `hasMetadata` → resto).
- El `IpcHandler` de `shell.qml` (target `selene`) no expone ninguna función de
  media: por eso el teclado no tiene forma de entrar.

## Decisions

- **Alcance partido por repositorio.** Este cambio entrega la mitad de Selene:
  tres funciones IPC y sus contratos. El cambio de binds en
  `home/.config/hypr/hyprland.lua` y el bump del submódulo viven en
  `MrUse77/MoonArch` y quedan **fuera de esta rama**.
- **dotfiles bloqueado.** `~/Dev/dotfiles` tiene una sesión RDD activa; no se
  escribe ahí hasta que esa sesión cierre. Sin ese cambio, las teclas siguen sin
  funcionar en runtime: esta rama es una precondición, no la solución visible.
- **Sin `playerctl`.** No se instala ni se declara el binario: el objetivo es
  eliminar la dependencia, no repararla.
- **Nombres IPC en camelCase sin guiones**, alineados con el resto del handler
  (`themeReload`, `clearNotifs`, `toggleDashboard`): `mediaPlayPause`,
  `mediaNext`, `mediaPrev`.
- **Sin OSD para media.** El OSD es reactivo a PipeWire y su spec
  (`openspec/specs/osd/spec.md`) es volumen-only. Mostrar feedback de transporte
  es otro cambio, no un extra de este.
- **Guardas, no errores.** Sin jugador o sin capacidad, la función IPC no hace
  nada; la guarda vive en `Media.qml` y no se duplica en `shell.qml`.

## Non-goals

- Cambiar binds de Hyprland, autostart, o cualquier archivo de `MoonArch`.
- Instalar o empaquetar `playerctl` / `playerctld`.
- OSD, notificaciones o cualquier feedback visual del transporte.
- Tocar `openspec/config.yaml` o el spec de `ipc`: la función nueva se documenta
  primero acá y su spec formal pertenece a un `changes/` propio si el equipo lo
  quiere.

## Tasks

- [x] **T1 — Contratos primero (rojo).** Extender `tests/test_media_contracts.py`:
      Declarar `SHELL_QML = PROJECT_ROOT / "shell.qml"` y agregar un test que exija,
      dentro del `IpcHandler` de `shell.qml` (`target: "selene"`, líneas 56–76), las
      funciones `mediaPlayPause`, `mediaNext` y `mediaPrev`, cada una delegando en
      `Media.togglePlaying()`, `Media.next()` y `Media.previous()` respectivamente.
      Correr y confirmar rojo. Evidencia: rojo observado —
      `test_ipc_handler_exposes_media_transport_functions` FAIL con
      `IpcHandler(target "selene") must declare mediaPlayPause() with an empty
      parameter list`, `Ran 7 tests / FAILED (failures=1)`, con los 6 tests
      preexistentes en verde.
      Descartado del plan original: la aserción "`shell.qml` no menciona `playerctl`".
      Es vacua — el archivo nunca lo mencionó y la dependencia vive en otro repo —
      así que no guarda nada. Ningún test de este repo puede cubrir esa dependencia.
- [x] **T2 — Implementar las tres funciones IPC (verde).** `shell.qml`, dentro del
      `IpcHandler` existente, mismo estilo de una línea que el resto.
      Evidencia: verde observado — `Ran 7 tests / OK`, y discovery `Ran 64 tests /
      OK` (era 63). Las tres líneas quedaron al final del bloque, sin guardas
      duplicadas y sin imports nuevos.
- [x] **T3 — Puerta real del CI, en cuatro gates.** Evidencia: los cuatro gates en
      verde — discovery `Ran 64 tests / OK / exit 0` (baseline 63); `qmltestrunner`
      3/3 suites (16+11+41 casos) con exit combinado 0; `qmllint 6.11.2
      --missing-property error` sobre 46 archivos, exit 0, 62 diagnósticos
      idénticos al árbol prístino de HEAD y **cero en `shell.qml`**; `actionlint`
      ausente localmente y este cambio no toca workflows. Chequeo de mutación sobre
      copia en `/tmp`: borrar las tres funciones, cruzar `mediaNext`→`previous()` y
      moverlas fuera del `IpcHandler` fallan los tres; reordenarlas no.
      1. `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v`
         (4 módulos, 63 casos)
      2. `qmltestrunner` sobre las 3 suites `tests/*/tst_*.qml`, con
         `QT_QPA_PLATFORM=offscreen`
      3. `qmllint --missing-property error` sobre todos los `.qml`/`.js` (excluyendo
         `.git`, `.atl`, `.zcode`, `.pi`) — **es el gate que ve las líneas nuevas de
         `shell.qml`**, y este repo ya tuvo una regresión de `missing-property`
         silencioso (`test_ci_lint_gate_fails_on_missing_property`)
      4. `actionlint` sobre los workflows (no lo toca este cambio; se corre igual)
      El plan original decía "los cinco suites de tests/": son **4 módulos Python +
      3 suites QML**, y ninguno de los dos números es 5. El 5 salió de contar los
      `.pyc` de `tests/__pycache__`, que incluyen un huérfano sin fuente
      (`test_notification_store_contracts`, sin `.py` ni referencia en CI).
      Defecto propio, encontrado al verificar y corregido antes del commit: el
      contrato nuevo aislaba el bloque con conteo de llaves y un guard `assertLess`
      **inalcanzable** — borrar la llave de cierre del `IpcHandler` la absorbía
      `ShellRoot` y el test seguía en verde con el alcance degradado en silencio.
      Reemplazado por una precondición de balance de llaves sobre `shell.qml`, más
      el `assertIsNotNone` como guarda secundaria. La mutación ahora falla con
      `shell.qml must be brace-balanced for the IpcHandler scan to be sound`.
- [ ] **T4 — Commit de unidad de trabajo.** Rama `feat/media-keys-ipc`. Incluye
      `shell.qml`, `tests/test_media_contracts.py` y este documento: `odd/` no está
      en `.gitignore`, así que el doc del change entra en el commit en vez de quedar
      untracked para siempre. Evidencia: hash.
- [ ] **T5 — BLOQUEADO (MoonArch).** Reemplazar los cuatro binds de transporte en
      `home/.config/hypr/hyprland.lua:465-469` de `~/Dev/dotfiles` por
      `qs -c selene ipc call selene mediaPlayPause|mediaNext|mediaPrev`, preservar
      `locked = true`, y bumpear el submódulo. `XF86AudioPlay` y `XF86AudioPause`
      mapean ambos a `play-pause`, así que los dos van a `mediaPlayPause`: cuatro
      binds, tres funciones. **No se toca**: decisión explícita del usuario en la
      sesión del 2026-09-19 (hay una sesión RDD activa en `dotfiles`).

## Follow-ups registrados (no son tareas de este cambio)

- Deploy vivo: `~/.config/quickshell/selene` es copia **y está más atrás que
  `main`** (20 divergencias, predata `0e5e18e`), así que "redeployar y recargar" no
  es un `rsync` de este change: arrastra todo lo que `main` tiene de más. Decisión
  del usuario, no automática, y sujeta a que `dotfiles` se destrabe.
- El ROADMAP no registra este cambio. Si el trabajo se vuelve visible para terceros,
  conviene una entrada en "De este lado (Selene)".
- **Identidad git rota en este clone, preexistente.** `.git/config` tiene
  `user.name = user.email` desde el 16 sep 08:25, así que cinco commits ya salieron
  con autor `user.email <agusdor14@hotmail.com>` (`9a04360`, `402c0b1`, `1808a31`,
  `71d8fbe`, `f7a6619`). El transporte por SSH no tiene relación: `remote.origin.url`
  define autenticación, `user.name`/`user.email` definen la metadata del commit.
  El commit de T4 se hizo con `-c user.name=MrUse77` para no ensuciar más el
  historial; el config del repo sigue como estaba, por decisión del usuario. Los
  cinco commits ya están en `origin/main`, así que arreglarlos sería reescritura de
  historia y no se propone.
- Selección con múltiples fuentes: `choosePlayer` prioriza `isPlaying` y desempata
  por `stableId` alfabético. Con dos jugadores reproduciendo a la vez, las teclas
  actúan sobre el primero alfabético. Documentado, no corregido acá.

## Review de handoff (sesión 2026-09-19, segunda)

Verificación read-only contra el repo real antes de ejecutar. Cierra sin defectos:
rama y HEAD, baseline verde (`test_media_contracts` = 6 tests OK; discovery = 63
casos, exit 0), API de `Media.qml` con sus guardas, `IpcHandler target: "selene"`
en `shell.qml:56-76` sin media, `qmldir:8` con `singleton Media Media.qml`,
`playerctl` ausente con `wpctl`/`brightnessctl` presentes, y los cuatro binds
verificados en el repo **y** en el config vivo. `qmllint` y `qmltestrunner`
están instalados localmente, así que T3 es corrible sin contenedor.

Riesgo de regresión descartado: los 47 casos de `test_selene_corrections.py`
verifican funciones IPC por patrón de existencia, no por conjunto exhaustivo;
agregar tres funciones no puede romperlos.

Correcciones aplicadas al plan original, todas ya incorporadas arriba: el conteo
"cinco suites", la puerta de T3 sub-especificada (faltaba el lint, que es el gate
relevante), la aserción vacua de `playerctl`, la salida literal esperada de
`git status --short` (imprime `?? odd/` por colapso de directorio; va con `-uall`),
la identificación del repo MoonArch, y el drift del deploy vivo.

Observación de proceso: T1 y T2 tocan dos archivos no triviales, así que la
implementación no va inline.

## Handoff anterior (sesión 2026-09-19, primera) — superado

Estado al cortar: **T1 a T4 sin ejecutar**. Esta rama tiene solo el documento que
estás leyendo, sin commitear. `tests/test_media_contracts.py` y `shell.qml` están
intactos en `main` (`0e5e18e`).

Por qué se cortó: la sesión anterior corría en `/home/agustin/Dev/Lab` (repo
contenedor sin commits, HEAD sin nacer). Ahí **ningún** subagente arranca: el
registro de worktree falla con `could not register launched worktree`, y el
guard de ODD frena el segundo archivo inline. Los triggers de delegación son
insatisfacibles en ese layout y el confinamiento es "mismo clone", así que
`Lab/QML` (clone independiente) queda fuera del alcance de cualquier worker
lanzado desde `Lab`. Desde este repo, los subagentes funcionan normal.

Comandos de arranque en la sesión nueva (cwd `/home/agustin/Dev/Lab/QML`):

```sh
cd /home/agustin/Dev/Lab/QML
git status --short          # espera: ?? odd/tasks/media-keys-selene-owned.md
git branch --show-current   # espera: feat/media-keys-ipc
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_media_contracts -v   # baseline verde (6 tests)
```

Recordatorios para quien continúe:

- El runner es stdlib `unittest`; `pytest` no está instalado en este entorno.
- `dotfiles` está fuera de alcance: tiene una sesión RDD activa (T5 sigue bloqueada).
- El primer commit de la rama debería acompañar a T1/T2, no ir solo con este doc.
- La decisión de deploy vivo (T6 en el tablero) es del usuario, no del agente.

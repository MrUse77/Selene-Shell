# Tasks: superficies de fallo de `Commands`

## Objetivo

Cerrar los tres advisories que dejó el review RDD del cambio de #9
(`feat/configurable-tool-commands`, mergeado como `4e98832`):

- **#25** — `fix(commands)`: el lanzamiento tracked no sobrevive un reload del shell.
- **#26** — `fix(commands)`: la degradación visible puede volver a ser muda.
- **#27** — `test(commands)`: cubrir los caminos de fallo de `Commands`.

Los tres comparten superficie (`Services/Commands.qml`, `Modules/Dashboard` y
`tests/`), así que se entregan como **un PR con tres work-unit commits**.

## Problema

`Services/Commands.qml` (introducido en #9) lanza **todo** con un
`Quickshell.Io.Process` tracked creado por `Component.createObject`. Ese objeto
es hijo del singleton, así que el reload de Quickshell lo destruye, y
`Process::~Process()` mata al hijo (`src/io/process.cpp:31-40`). La base usaba
`Quickshell.execDetached`, cuyos hijos estaban deliberadamente desacoplados.

La consecuencia no es simétrica: para `paru`, `pavucontrol` o `wl-copy` es una
tarea abortada a mitad de camino; para `hyprlock` es peor — **un reload mientras
la pantalla está bloqueada mata al hijo y la sesión queda desbloqueada**.

Además, el feedback de #9 tiene dos agujeros:

1. `Commands.notify` usa `Quickshell.execDetached` sin camino de fallo: si
   `notify-send` falta o el comando está mal configurado, sólo queda un
   `console.log` y todos los widgets vuelven al clic mudo.
2. `Dashboard.refreshBt` omite el sondeo cuando el parseo falla, sin señal.

Y los contratos de #9 verifican estructura por substring, no comportamiento:
los tres caminos de fallo (parseo inválido, `FailedToStart` sin
`onStarted`/`onExited`, exit distinto de 0) no se ejercitan en ningún test.

## Por qué

- Es la cola que el propio review RDD dejó abierta, con causa raíz verificada en
  la fuente de Quickshell.
- El caso `hyprlock` es de seguridad, no de comodidad.
- El repo ya tiene la convención para hacer esto testeable: lógica pura en
  `Services/*.js` con suite de `qmltestrunner` (`BatteryLogic`, `GeometryLogic`,
  `NotificationState`, `OverlayState`, `MediaLogic`, `OperationState`).

## Alcance autorizado

- Repositorio: `MrUse77/Selene-Shell`.
- Rama: `feat/commands-failure-surfaces` desde `main` (`4e98832`).
- Issues de entrega: `#25`, `#26`, `#27` (un PR que cierra las tres).
- Archivos esperados: `Services/CommandLogic.js` (nuevo), `Services/Commands.qml`,
  `Services/LauncherLogic.js`, `Modules/Bar/AudioWidget.qml`,
  `Modules/Bar/UpdatesWidget.qml`, `Modules/Launcher/Launcher.qml`,
  `Modules/Dashboard/Dashboard.qml`, `Modules/PowerMenu/PowerMenu.qml`,
  `tests/commands/tst_commands_logic.qml` (nuevo), `tests/test_commands_contracts.py`,
  `tests/test_selene_corrections.py`.
- Fuera de alcance: MoonArch, dotfiles, `~/.config`, Quickshell live, el
  notificador como sistema de toasts nuevo, `Services/Theme.qml`, el pipeline
  `sh -c` propio de `Services/Updates.qml` y `Services/Hardware.qml`, y el
  circuito del selector de temas.

## Decisiones

### D1 — Dos semánticas de lanzamiento, explícitas en el nombre

- `Commands.launch(result, title)` — **tracked** (lo que ya existe): el proceso
  es hijo del singleton, da `started`/`exited`/stderr y muere con el shell.
  Para comandos cortos donde el código de salida es la única señal real.
- `Commands.launchDetached(result, title)` — **detached**:
  `Quickshell.execDetached(args)`. El hijo sobrevive el reload y no reporta
  nada. Para lo que dura más que la shell o no debe morir con ella.

### D2 — Clasificación por comando, con el motivo escrito

| Comando | Semántica | Motivo |
| --- | --- | --- |
| `audio` (pavucontrol) | detached | GUI de vida larga; el exit code no le importa a nadie |
| `updates` (`ghostty -e paru`) | detached | terminal interactiva: abortarla a mitad de update es el daño |
| `lock` (hyprlock) | detached | seguridad: un reload mientras está bloqueada no debe desbloquear |
| `copy` (wl-copy) | detached | vive para ser dueño de la selección; matarlo la pierde |
| `notifier` (notify-send) | detached | fire-and-forget; su fallo se cubre con D4 |
| acciones de sesión del Dashboard (`systemctl suspend/reboot/poweroff`) | detached | fire-and-forget sin superficie de exit code; sobrevivir es gratis |
| `lock` en PowerMenu | detached | mismo caso que `lock`, con el cierre del menú atado a la sonda |
| acciones de sesión de PowerMenu (`systemctl`, `hyprctl dispatch exit`) | **tracked** (sin cambio) | la denegación de polkit sólo se ve en el exit code, y su `errorText` es la superficie del módulo; el tradeoff (una ventana de reload de milisegundos) queda documentado acá y en el comentario del sitio |
| `bluetoothctl`, `find`, `hyprctl` de consulta | tracked (sin cambio) | necesitan stdout o exit code |

### D3 — Sonda de ejecutabilidad: `sh` + `command -v`, nombre como parámetro

Decisión del maintainer. `CommandLogic.probeArgv(name)` devuelve exactamente:

```
["sh", "-c", "command -v -- \"$1\" >/dev/null 2>&1", "selene-command-probe", name]
```

- El script es **constante**; el nombre viaja como parámetro posicional (`$1`) y
  **nunca** se interpola en la cadena del `-c`. Es la regla de #9 y un test la
  fija: el nombre no puede aparecer dentro del script.
- Es la misma autoridad que va a hacer el `exec` (PATH + bit de ejecución), no
  una reimplementación del lookup del loader.
- La sonda es un `Process` tracked de vida útil de milisegundos; si el shell
  recarga justo en esa ventana, no se lanza nada. Tradeoff aceptado y documentado.
- Sólo la usan los lanzamientos detached: los tracked ya tienen `FailedToStart`.

### D4 — Fallback del notificador: log de diagnóstico persistente

`Commands.notify` sonda primero al notificador (D3). Si no se puede ejecutar:

- `console.warn` con el mensaje completo (queda en el log de Quickshell),
- y una línea en `Quickshell.statePath("commands.log")`, acotada a las últimas
  `CommandLogic.LOG_MAX_LINES` (50) líneas, escritura por `FileView`.

No se agrega un sistema de toasts ni estado global: la superficie secundaria es
diagnóstico recuperable, que es lo que pedía la issue.

### D5 — Dashboard: el sondeo de Bluetooth deja de ser mudo

`refreshBt` distingue tres estados: `btKnown` (hubo lectura), el valor `btOn`, y
`btUnavailable` cuando el parseo falla o el proceso del sondeo no arranca. La
tarjeta muestra "Bluetooth unavailable" en vez de mentir con el último valor.

### D6 — Lógica pura y testeable

`Services/CommandLogic.js` (`.pragma library`, sin dependencias de Qt) concentra
lo que se puede ejecutar en un test:

- `resolve(envValue, settingValue, fallback)` — la cadena de precedencia
  (primer string no vacío gana). Es la regla documentada; `Commands._resolve`
  delega acá. `Theme.pick` queda intacto para sus propias claves.
- `probeArgv(name)` — D3.
- `failureMessage(event, detail)` — **tabla de decisión de los tres caminos de
  fallo**: `parse`, `create`, `start` (`FailedToStart`), `probe`, `exit`.
- `exitMessage(exitCode, stderr, stdout)` — precedencia del mensaje de salida.
- `logLine(stamp, title, message)` y `appendLog(existing, line, maxLines)`.

`Services/LauncherLogic.js` gana `okResult(args)`, el shape de éxito que hoy se
reconstruye a mano en `Modules/Launcher/Launcher.qml:243`.

### D7 — Modo TDD y gates

- Modo TDD: **ordinary** (no hay instrucción `strict_tdd` de sesión o proyecto).
  La suite nueva se escribe junto al cambio; el rojo se observa cuando hace
  falta mostrar que el contrato sirve (mutaciones).
- Runner: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v`.
- Gates completos: unittest, `qmltestrunner` sobre `tests/*/tst_*.qml` con
  `QT_QPA_PLATFORM=offscreen`, `qmllint --missing-property error` sobre
  `.qml`/`.js` (excluye `.git`, `.atl`, `.zcode`, `.pi`), y `actionlint` si está
  disponible.
- RDD: `on` (global). El candidato del review es el **slice de PR** (los tres
  commits).
- Estrategia de entrega: `ask-on-risk`. Pronóstico: ~500 líneas autorizadas
  contando este documento; si el PR supera 400, se pregunta antes de abrir.

## Tasks

- [x] **T1 — Semántica detached + sonda (#25).**
      Crear `Services/CommandLogic.js` con `resolve`, `probeArgv` y la tabla de
      decisión de fallo; agregar `Commands.launchDetached` (sonda → notify o
      `execDetached`); migrar los consumidores de D2 (AudioWidget, UpdatesWidget,
      Launcher/copy, Dashboard/acciones de sesión); en PowerMenu llevar `lock` a
      detached con el cierre del menú atado al resultado de la sonda y dejar
      `systemctl`/`hyprctl` tracked con el motivo escrito. Suite nueva
      `tests/commands/tst_commands_logic.qml` para `resolve`, `probeArgv` (incluye
      que el nombre no viaja dentro del script) y la decisión de la sonda;
      contratos nuevos en `tests/test_commands_contracts.py`.
- [x] **T2 — Fallback del notificador y Bluetooth visible (#26).**
      `Commands.notify` con sonda previa, `console.warn` y log acotado en
      `Quickshell.statePath("commands.log")` (D4). `Dashboard.refreshBt` con
      estado `btUnavailable` visible (D5). Tests de `logLine`/`appendLog` y
      contratos de la superficie nueva.
- [ ] **T3 — Caminos de fallo ejecutables y shape unificado (#27).**
      Completar la suite con la tabla de los tres caminos (`parse`, `start` sin
      `onStarted`, `exit != 0`) y la precedencia del mensaje de exit; `okResult`
      en `LauncherLogic` usado por `Commands.argv` y por `Launcher.qml` (fin del
      record fabricado a mano); contratos que fijen el shape productor/consumidor.
- [ ] **T4 — Verificación completa y evidencia.**
      Correr los cuatro gates, las mutaciones (sonda con el nombre interpolado,
      precedencia cruzada, mensaje de exit invertido, record a mano) y dejar la
      tabla de evidencia en este documento.

## Criterios de aceptación

- [ ] Las tareas que deben sobrevivir al shell (D2) ya no mueren con un reload:
      ninguna usa un `Process` tracked hijo del singleton.
- [ ] Un binario ausente en un lanzamiento detached produce feedback visible
      (sonda) y no un clic mudo.
- [ ] El fallo del notificador deja rastro recuperable (log de diagnóstico) y no
      sólo un `console.log`.
- [ ] El sondeo de Bluetooth no vuelve a mostrar un valor viejo sin señal.
- [ ] Los tres caminos de fallo están cubiertos por tests ejecutables, no por
      substring.
- [ ] El shape del record `{ok, args, error}` tiene un solo productor por camino.
- [ ] Los gates pasan y `qmllint --missing-property error` queda en `rc=0`.

## Progreso

- [x] Exploración: inventario completo de call sites de `Commands` y de la API
      real de Quickshell (`Process::~Process` mata al hijo; `Process.startDetached`
      y `Quickshell.execDetached` existen; `Quickshell.statePath(path)` existe).
- [x] Decisiones D1–D7 tomadas con el maintainer (entrega: un PR; sonda: `sh` +
      `command -v`).
- [x] Rama creada desde `main` (`4e98832`).
- [x] T1 — `Services/CommandLogic.js` (43 líneas), `launchDetached` + sonda en
      `Commands.qml`, migración de los cinco sitios detached, suite nueva en
      `tests/commands/tst_commands_logic.qml` (9 casos) y 4 contratos nuevos.
- [ ] T3–T4.

## Evidencia

### T1 (#25)

- **Sonda (D3)**: `CommandLogic.probeArgv("pavucontrol")` →
  `["sh", "-c", "command -v -- \"$1\" >/dev/null 2>&1", "selene-command-probe", "pavucontrol"]`.
  `args[2]` es constante byte a byte; el nombre sólo es alcanzable en `args[4]`.
  Un caso con `$(...)`, backticks y comillas verifica que no aparece en el script.
- **Mensajes**: idénticos a los de #9 (`"Unable to create the process"`,
  `"Unable to start " + program`, y el `error` de parseo), ahora en la tabla
  `failureMessage` y cubiertos por test.
- **Gates**: `unittest discover -s tests -p test_commands_contracts.py` → 12
  tests OK; `-p test_selene_corrections.py` → 47 tests OK; suite Python completa
  → 96 tests OK; `qmltestrunner` (`/usr/lib/qt6/bin/`, Qt6) → commands 9/0,
  battery 16/0, geometry 10/0, notification-state 11/0, overlay-state 41/0;
  `qmllint --missing-property error` → `rc=0` en los 8 archivos tocados.
- **Hallazgo del entorno**: hay **dos** binarios con el mismo nombre y sólo uno
  sirve. `/usr/bin/qmltestrunner` es de Qt5 (`libQt5QuickTest`) y falla mudo con
  estas suites (rc=1, 0 bytes de salida, también en las preexistentes);
  `/usr/bin/qmllint` es `qmllint 1.0`, una herramienta distinta. Los correctos
  son los de Qt6 (`/usr/lib/qt6/bin/…`, 6.11.2), que son los que usa el CI.
- **Sin verificar**: comportamiento en vivo (sonda ante `FailedToStart` y
  supervivencia real del hijo detached). Se infiere de la fuente de Quickshell,
  no se observó: no hubo runtime por autorización.

### T2 (#26)

- **Notificador**: `notify` sondea el binario antes de entregar; si no puede
  correr (o el comando no parsea) va a `_diagnose`, que hace `console.warn` y
  anexa una línea acotada a `Quickshell.statePath("commands.log")` con
  `FileView.setText`. `CommandLogic.logLine` colapsa `\r`/`\n` para que el
  stderr multilínea de una herramienta no pueda romper el formato de una línea
  por evento, y `appendLog` conserva sólo las últimas `LOG_MAX_LINES` (50).
- **Dashboard**: `btUnavailable` se declara cuando el argv no parsea, cuando el
  proceso del sondeo no arranca (`FailedToStart`) y cuando sale distinto de 0.
  El cierre del hueco que quedaba (ver «Tradeoffs») es salida 0 **sin ninguna
  línea reconocida**, que se difiere un turno con `Qt.callLater` porque
  `QProcess` puede emitir `finished` con datos todavía en el pipe.
- **Gates (verificación independiente, `gentle-ai-verify`)**: `unittest
  discover -s tests` → **99 tests, OK** (`rc=0`); `qmltestrunner` Qt6 → battery
  16/0, **commands 15/0**, geometry 10/0, notification-state 11/0, overlay-state
  41/0 (93 pasados, 0 fallados); `qmllint --missing-property error` (Qt6, 41
  archivos) → `rc=0`, 70 warnings y 0 errores.
- **Mutaciones (copia en `/tmp`, restaurada entre cada una)**: interpolación del
  nombre en el script de la sonda → `tst_commands_logic` 2 fallos; precedencia de
  `resolve` invertida → 1 fallo; `execDetached` antes de la sonda → contrato
  `test_launch_detached_probes_before_spawning`; `_diagnose` sin `console.warn` →
  contrato `test_notify_failure_is_diagnosed_with_warn_and_bounded_log`; tope del
  log en 500 → fallan **suite y contrato**; sondeo de Bluetooth mudo → contrato
  `test_dashboard_bluetooth_poll_surfaces_the_unavailable_state`. Ninguna
  mutación sobrevivió.

### Tradeoffs aceptados

- **Todo lanzamiento detached pierde el exit code**, no sólo el de la sonda: un
  `wl-copy` que falla al tomar la selección y un `hyprlock` que sale de inmediato
  con error ya no producen señal. El caso `hyprlock` es el más sensible y queda
  como el candidato natural de un follow-up que verifique el bloqueo con
  `hyprctl` después de lanzar (no se hace acá para no meter una dependencia del
  formato de Hyprland en este PR).
- **`notify` es asincrónica** (primero la sonda): un reload dentro de esa
  ventana de milisegundos pierde la notificación, el mismo tradeoff de
  `launchDetached`, documentado en el encabezado del servicio.
- **Log de diagnóstico**: si el archivo no se leyó todavía, la primera línea
  arranca de un buffer vacío, así que se pierde el contenido previo del archivo
  en ese único caso. Documentado en el código.
- **PowerMenu `systemctl`**: se queda tracked a propósito, así que una denegación
  de polkit sigue siendo visible en `errorText` a cambio de una ventana de
  reload de milisegundos.

### Baseline

- `main` (`4e98832`, mismo árbol que `0f43cce`) tenía los 4 checks de CI en verde
  (run 35904068728): contratos Python, QML tests, qmllint y actionlint.
  `actionlint` no está instalado localmente; lo corre el CI.
- Rollback boundary: revertir los tres commits de esta rama elimina exactamente
  los paths de T1–T3; no arrastra trabajo no relacionado de `main`.

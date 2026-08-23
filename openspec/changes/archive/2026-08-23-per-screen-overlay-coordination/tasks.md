# Tasks: Coordinación de Overlays Interactivos por Pantalla

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 330–390 (helper+tests 100–135, coordinator+register 95–115, migration 120–140) |
| 400-line budget risk | Medium |
| Chained PRs recommended | No (viable within budget if tests stay focused) |
| Suggested split | Single PR; if fullscreen detection or test harness exceeds ~20 extra lines, split into PR 1 (reducer+tests+singleton) → PR 2 (UI/IPC migration+runtime) |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

```text
Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium
```

**Apply readiness (slice 3):** Foundation at `752f07e`; cross-output `PanelWindow` retarget replaced with fixed per-screen instances via `Variants`. Barrier code/tests removed. Deterministic tests to be confirmed fresh by the current apply actor. Slice diff target stays within the 400-line budget. Runtime retest T4.2–T4.8 is pending parent execution.

---

## Prerrequisitos Bloqueantes

Estos prerrequisitos deben resolverse antes de cualquier apply con runtime bearing.

- [x] **P0.1 — Git common directory confirmado.** `/home/agustin/Dev/Lab/QML/.git/HEAD` legible y `git status` funcional. Resuelto por contexto del orquestador antes del lanzamiento. **Status: RESOLVED.**
- [x] **P0.2 — Test runner determinista confirmado.** El runner funcional es `/usr/lib/qt6/bin/qmltestrunner` (Qt 6.11.2); `/usr/bin/qmltestrunner` es Qt5 y no ejecuta estos tests. Comando determinista:
  ```
  QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/overlay-state -import . -o -,txt
  ```
- [x] **P0.3 — `gentle-ai sdd-attempt acquire` disponible.** El orquestador ejecutó `gentle-ai sdd-attempt acquire` y el proveedor retornó `state: proceed` para work unit `overlay-coordination-apply` (max changed lines 400, max attempts 2). Resuelto por contexto del orquestador. **Status: RESOLVED.**

---

## Native Attempt Ordering (Orchestrator-Owned)

`gentle-ai sdd-attempt acquire` y `settle` son responsabilidad exclusiva del orquestador. Ninguna tarea de implementación los ejecuta directamente.

- **Acquire**: el orquestador llama `gentle-ai sdd-attempt acquire` **antes** de lanzar el primer actor `sdd-apply` que cree tests, mutar archivos de producción, o ejecutar test runners. Esto ocurre después de resolver P0.1.
- **Settle**: el orquestador llama `gentle-ai sdd-attempt settle` **después** de que el actor acotado complete su ejecución, pasando evidencia real (resultado de tests, changed lines, etc.).
- Los actores `sdd-apply` nunca invocan acquire/settle ni inventan tokens/request IDs.

---

## Work Unit 1: RED — Tests del Reducer de Estado (Qt Quick Test)

**Objetivo:** Codificar los tests que fallan contra un helper que aún no existe. Estos tests verifican transiciones de estado puras sin dependencias de Quickshell/Hyprland. Se ejecutan con `qmltestrunner`.

**Layout:**
```
tests/overlay-state/
  tst_overlay_state.qml    ← QML TestCase que importa Services/OverlayState.js
```

**Comando determinista:**
```
QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/overlay-state -import .
```

**Nota sobre imports:** `tst_overlay_state.qml` importa `Services/OverlayState.js` como módulo JS. El reducer es puro: recibe estado, acción, lista de screens y bandera fullscreen; retorna `{state, accepted}`. Los tests simulan screens como objetos JS con `{name: "DP-2"}` etc.

**Dependencias:** P0.2 (resuelto).

- [x] **T1.1 — RED: Exclusividad global.** Test: dado estado cerrado, `open("launcher", {source:"widget", screen:screenA, explicit:true})` produce `{activeKind:"launcher", targetScreen:screenA}`. Luego `open("dashboard", {source:"widget", screen:screenB, explicit:true})` produce `{activeKind:"dashboard", targetScreen:screenB}` — launcher fue reemplazado.
- [x] **T1.2 — RED: Open idempotente del mismo kind.** Test: dado launcher abierto en screenA, `open("launcher", {source:"ipc", screen:screenB, explicit:true})` NO cambia pantalla — conserva screenA. Retorna `accepted: true` sin mutar.
- [x] **T1.3 — RED: Toggle cierra, doble toggle restaura.** Test: desde cerrado, `toggle("launcher", origen válido)` → abierto. Otro `toggle("launcher", origen válido)` → cerrado. Estado final: `{activeKind:"", targetScreen:null}`.
- [x] **T1.4 — RED: Captura inmutable — cambio de foco no mueve.** Test: launcher abierto en screenA. Simular cambio de foco (la lista de screens no cambia, solo el foco). Consultar estado: `targetScreen` sigue siendo screenA. El reducer no recibe ni procesa eventos de foco.
- [x] **T1.5 — RED: Cierre idempotente.** Test: desde estado cerrado, `close()` → `{activeKind:"", targetScreen:null}`, `accepted: true`. `close("launcher")` cuando launcher no está abierto → sin cambio, `accepted: true`.
- [x] **T1.6 — RED: Origen con pantalla removida descartado.** Test: dado launcher abierto en screenA, screenA se remueve de la lista de screens vivas. `open("launcher", {source:"widget", screen:screenA, explicit:true})` → `accepted: false`, estado cerrado (el cierre por hotplug ya procesó).
- [x] **T1.7 — RED: IPC con origen vigente durante hotplug.** Test: launcher abierto en screenA. screenA removida. `toggle("launcher", {source:"ipc", screen:screenB, explicit:true})` con screenB vigente → `accepted: true`, estado `{activeKind:"launcher", targetScreen:screenB}`.
- [x] **T1.8 — RED: Widget con pantalla propietaria removida descartado.** Test: launcher abierto en screenA. screenA removida. `open("launcher", {source:"widget", screen:screenA, explicit:true})` → `accepted: false`, estado cerrado.
- [x] **T1.9 — RED: Fallback sin pantallas.** Test: lista de screens vacía. `resolveFocusedScreen()` retorna `null`. `open` con screen null → `accepted: false`.
- [x] **T1.10 — RED: Cierre por hotplug (closeForScreen).** Test: launcher abierto en screenA. `closeForScreen(screenA)` → cerrado. `closeForScreen(screenB)` (otra pantalla) → sin cambio.
- [x] **T1.11 — RED: Policy fullscreen — pasivo rechazado, explícito aceptado.** Test: con bandera fullscreen activa en screenA, `open("launcher", {source:"passive", screen:screenA, explicit:false})` → `accepted: false`. `open("launcher", {source:"widget", screen:screenA, explicit:true})` → `accepted: true`.
- [x] **T1.12 — RED: Secuencia rápida launcher→dashboard→power.** Test: desde cerrado, `open("launcher")`, `open("dashboard")`, `open("power")` en secuencia. Estado final: `{activeKind:"power", targetScreen:screenC}`. Exactamente uno abierto.
- [x] **T1.13 — RED: Kind inválido descartado.** Test: `open("calendar", origen)` → `accepted: false`, estado sin cambio. Solo "launcher", "dashboard", "power" son válidos.

**Verificación:** Todos los tests fallan (RED). El helper `Services/OverlayState.js` aún no existe. `qmltestrunner` reporta 13 failures.

**Rollback:** Eliminar `tests/overlay-state/`. Sin impacto en producción.

---

## Work Unit 2: GREEN — Helper Puro + Coordinador Singleton

**Objetivo:** Implementar el reducer puro y el singleton adaptador. Los tests de WU1 pasan. El coordinador se registra pero ningún consumidor lo usa aún.

**Archivos:**
- `Services/OverlayState.js` (NUEVO — reducer puro)
- `Services/OverlayCoordinator.qml` (NUEVO — singleton adaptador)
- `Services/qmldir` (MODIFICAR — agregar línea singleton)

**Dependencias:** WU1 (tests RED existentes).

- [x] **T2.1 — GREEN: Implementar `Services/OverlayState.js`.** Reducer puro que exporta `reduce(state, action, liveScreens)` y `resolveFocusedScreen(focusedName, liveScreens)`. Sin imports de Quickshell/Hyprland. Funciones puras: `open`, `toggle`, `close`, `closeForScreen`. Valida kind contra `["launcher","dashboard","power"]`. Valida screen contra `liveScreens`. Retorna `{state, accepted}`.
- [x] **T2.2 — GREEN: Tests de WU1 pasan.** Ejecutar `QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/overlay-state -import .`. Todos los tests de T1.1–T1.13 pasan. Si algún test revela un edge case no contemplado en el diseño, documentar y ajustar el reducer sin cambiar el test (el test es la especificación).
- [x] **T2.3 — Implementar `Services/OverlayCoordinator.qml`.** Singleton que importa `QtQuick`, `Quickshell`, `Quickshell.Hyprland`. Propiedades privadas: `_activeKind: ""`, `_targetScreen: null`. Propiedades readonly públicas: `activeKind`, `targetScreen`, `isOpen`, `launcherOpen`, `dashboardOpen`, `powerOpen`, `targetScreenName`. Funciones públicas: `open(kind, origin)`, `toggle(kind, origin)`, `close(kind)`, `closeForScreen(screen)`, `isScreenValid(screen)`, `resolveFocusedScreen()`. Cada función construye la acción, llama al reducer con `Quickshell.screens` como liveScreens, y publica el resultado. Observa cambios en `Quickshell.screens` para cierre por hotplug: si `_targetScreen` ya no pertenece a la lista, ejecuta `closeForScreen(_targetScreen)`.
- [x] **T2.4 — Registrar singleton en `Services/qmldir`.** Agregar línea: `singleton OverlayCoordinator OverlayCoordinator.qml`. Verificar que el archivo parsea sin errores de sintaxis QML.
- [x] **T2.5 — Verificación estructural (Python).** Agregar a `tests/test_selene_corrections.py` o crear test nuevo: (a) `OverlayCoordinator.qml` existe y declara `_activeKind` y `_targetScreen` como propiedades asignables; (b) las proyecciones `activeKind`, `targetScreen`, `launcherOpen`, `dashboardOpen`, `powerOpen` son `readonly`; (c) `qmldir` contiene `singleton OverlayCoordinator`.

**Verificación:** Tests RED de WU1 pasan (qmltestrunner verde). Singleton registrado. Tests estructurales Python pasan. Ningún consumidor lo usa todavía — cero impacto en runtime.

**Rollback:** Eliminar `OverlayState.js`, `OverlayCoordinator.qml`, revertir línea en `qmldir`. Sin impacto en producción.

---

## Work Unit 3: Migración Atómica de Consumidores

**Objetivo:** Migrar TODOS los consumidores de `ShellState` para launcher/dashboard/power al coordinador en una sola unidad atómica. No se deja ventana con dos autoridades escribibles.

**Archivos modificados:**
- `Services/ShellState.qml` — retirar 3 booleans + 3 toggles
- `shell.qml` — IPC handlers migrados
- `Modules/Launcher/Launcher.qml` — screen/visible/focusable/close
- `Modules/Dashboard/Dashboard.qml` — screen/visible/focusable
- `Modules/PowerMenu/PowerMenu.qml` — screen/visible/focusable/close
- `Modules/Bar/Bar.qml` — indicador + clics + inyección de screen
- `Modules/Bar/MediaWidget.qml` — declarar screen prop, usar coordinador
- `Modules/Bar/PowerButton.qml` — declarar screen prop, usar coordinador

**Dependencias:** WU2 (coordinador funcional y registrado).

- [x] **T3.1 — Migrar `shell.qml` IPC handlers.** Los tres handlers `toggleLauncher/toggleDashboard/togglePower` ahora: (1) llaman `OverlayCoordinator.resolveFocusedScreen()` para capturar monitor enfocado en el instante; (2) construyen `origin = {source:"ipc", screen:resolved, explicit:true}`; (3) llaman `OverlayCoordinator.toggle(kind, origin)`. Los handlers de calendar/history/DND/calc quedan intactos con `ShellState`.
- [x] **T3.2 — Migrar `Modules/Launcher/Launcher.qml`.** Declarar `property var modelData` para recibir la pantalla desde `Variants`. Fijar `screen: modelData` (sin retargeteo reactivo). `visible` y `focusable` deben ser `OverlayCoordinator.launcherOpen && OverlayCoordinator.targetScreen === modelData`. Función `close()` llama `OverlayCoordinator.close("launcher")`. Preservar WlrLayer.Overlay, ExclusionMode.Ignore, anclajes, colores, animaciones.
- [x] **T3.3 — Migrar `Modules/Dashboard/Dashboard.qml`.** Mismo patrón: declarar `property var modelData`, fijar `screen: modelData`. `visible` y `focusable` deben ser `OverlayCoordinator.dashboardOpen && OverlayCoordinator.targetScreen === modelData`. El `Qt.callLater(refreshBt)` del toggle Bluetooth se mantiene; no forma parte de la barrera de screen-ready. Preservar layout, margins, Mpris, Bluetooth, DND (DND sigue en ShellState).
- [x] **T3.4 — Migrar `Modules/PowerMenu/PowerMenu.qml`.** Mismo patrón: declarar `property var modelData`, fijar `screen: modelData`. `visible` y `focusable` deben ser `OverlayCoordinator.powerOpen && OverlayCoordinator.targetScreen === modelData`. `close()` llama `OverlayCoordinator.close("power")`. Preservar layout, colores, MouseArea de dismiss.
- [x] **T3.5 — Migrar `Modules/Bar/Bar.qml`.** (a) `anyOverlay` lee `OverlayCoordinator.isOpen` en vez de los tres booleans de ShellState. (b) Indicador launcher: `active: OverlayCoordinator.launcherOpen`, `onClicked: OverlayCoordinator.toggle("launcher", {source:"widget", screen:root.modelData, explicit:true})`. (c) Indicador dashboard: `active: OverlayCoordinator.dashboardOpen`, `onClicked: OverlayCoordinator.toggle("dashboard", {source:"widget", screen:root.modelData, explicit:true})`. (d) Inyectar `screen: root.modelData` en `MediaWidget` y `PowerButton`.
- [x] **T3.6 — Migrar `Modules/Bar/MediaWidget.qml`.** Declarar `property var screen: null`. En `onClicked`: `OverlayCoordinator.open("dashboard", {source:"widget", screen:root.screen, explicit:true})`. Eliminar asignación directa `ShellState.dashboardOpen = true`.
- [x] **T3.7 — Migrar `Modules/Bar/PowerButton.qml`.** Declarar `property var screen: null`. `active: OverlayCoordinator.powerOpen`. `onClicked: OverlayCoordinator.toggle("power", {source:"widget", screen:root.screen, explicit:true})`.
- [x] **T3.8 — Retirar estados de `Services/ShellState.qml`.** Eliminar: `property bool launcherOpen`, `property bool dashboardOpen`, `property bool powerOpen`, `function toggleLauncher()`, `function toggleDashboard()`, `function togglePower()`. Conservar intactos: calendarOpen/Screen, historyOpen/Screen, dnd, unread, history, historyCap, toggleCalendar, toggleHistory, addHistory, clearHistory, evalExpr.
- [x] **T3.9 — Búsqueda dirigida: símbolos heredados eliminados.** Ejecutar grep en todo el proyecto confirmando CERO ocurrencias de: `ShellState.launcherOpen`, `ShellState.dashboardOpen`, `ShellState.powerOpen`, `ShellState.toggleLauncher`, `ShellState.toggleDashboard`, `ShellState.togglePower`. Si queda alguna, migrar antes de continuar.
- [x] **T3.10 — Búsqueda dirigida: sin asignaciones prohibidas al coordinador.** Grep confirmando CERO asignaciones a `OverlayCoordinator._activeKind`, `OverlayCoordinator._targetScreen`, `OverlayCoordinator.activeKind`, `OverlayCoordinator.targetScreen` fuera de `OverlayCoordinator.qml`. Las proyecciones readonly impiden escritura, pero verificar que ningún consumidor intenta asignarlas.
- [x] **T3.11 — Verificación estructural post-migración.** Extender tests Python: (a) `ShellState.qml` no declara `launcherOpen`, `dashboardOpen`, `powerOpen`, `toggleLauncher`, `toggleDashboard`, `togglePower`; (b) ningún archivo fuera de `OverlayCoordinator.qml` asigna a las propiedades privadas del coordinador; (c) `Launcher.qml`, `Dashboard.qml`, `PowerMenu.qml` leen `screen` de `OverlayCoordinator.targetScreen`; (d) `shell.qml` IPC usa `OverlayCoordinator.resolveFocusedScreen()` para los tres toggles.

**Verificación:** Todos los consumers migrados. ShellState sin los tres estados interactivos. Búsquedas dirigidas confirman ausencia de símbolos heredados. Tests estructurales pasan.

**Rollback:** Revertir los 8 archivos juntos. Restaura autoridad única de ShellState. Sin datos persistentes afectados.

---

## Work Unit 4: Verificación Estática y Runtime Acotado

**Objetivo:** Confirmar contratos estructurales y validar integración con dos monitores conectados.

**Precondición orchestrador:** Antes de lanzar el primer actor `sdd-apply` que ejecute este work unit, el orquestador debe haber llamado `gentle-ai sdd-attempt acquire` (P0.1 resuelto). El actor implementa; el orquestador liquida con `settle` al completar.

**Dependencias:** WU3 (migración completa).

- [x] **T4.1 — Ejecutar tests deterministas completos.** Verdes en este intento: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/overlay-state -import . -o -,txt` → 15 passed; `python -m unittest tests.test_overlay_foundation tests.test_selene_corrections -v` → 19 passed (1 test de barrera plegado en el contrato de estado privado del coordinador). Los contratos estructurales exigen instancias fijas por pantalla (`Variants` en `shell.qml`, `screen: modelData`, visible/focusable por kind + identidad de pantalla) y que `OverlayCoordinator.apply` siga ocultando el kind anterior antes de asignar `_targetScreen`. T4.2–T4.8 requieren runtime manual con dos monitores y permanecen sin marcar.
- [x] **T4.1a — Materialización fija por pantalla.** Reemplazar instancias globales de Launcher/Dashboard/PowerMenu en `shell.qml` por `Variants { model: Quickshell.screens; ... }`. En cada módulo declarar `property var modelData`, fijar `screen: modelData` y computar `visible`/`focusable` como `OverlayCoordinator.<kind>Open && OverlayCoordinator.targetScreen === modelData`. Eliminar del coordinador únicamente los tokens de la barrera screen-ready fallida: `_screenReady`, `_readyGeneration`, `screenReady`, `_markReady` y el `Qt.callLater` asociado a dicha barrera. El `Qt.callLater(refreshBt)` del Bluetooth del dashboard no se toca.
- [x] **T4.2 — Runtime: apertura desde widgets de barra (2 monitores).** Launcher en DP-2 y dashboard/power en HDMI-A-1 fueron confirmados durante la sesión con asistencia humana y capturas; MediaWidget no estaba visible por ausencia de MPRIS activo, con propagación de `screen` cubierta estructuralmente.
- [x] **T4.3 — Runtime: IPC con foco alternado.** PASS: launcher abrió en DP-2, permaneció allí al mover foco a HDMI-A-1 y dashboard lo reemplazó en HDMI-A-1.
- [x] **T4.4 — Runtime: reemplazo launcher→dashboard→power.** PASS: `hyprctl layers -j` y capturas confirmaron un único overlay y reemplazo por el último solicitado.
- [x] **T4.5 — Runtime: fullscreen con acción explícita.** UNAVAILABLE, no FAIL: no había ningún cliente fullscreen en DP-2 y no se forzó una ventana del usuario; la política explícito/pasivo permanece cubierta por tests deterministas.
- [x] **T4.6 — Runtime: desconexión de pantalla capturada.** PASS con output headless temporal `HEADLESS-1`: al removerlo el overlay cerró y no migró a DP-2/HDMI-A-1; ningún monitor físico fue desactivado.
- [x] **T4.7 — Limpieza post-runtime.** PASS: output temporal y artefactos `/tmp` eliminados, overlays cerrados, dunst intacto y una sola instancia saludable de Selene. La restauración exacta del cursor fue unavailable por tooling Wayland.
- [x] **T4.8 — Verificación final de compatibilidad.** PASS: nombres IPC preservados; calendario/historial disponibles; OSD y notificaciones fuera del diff; estructura visual sin cambios de alcance.

**Verificación:** Sin hallazgos FAIL. Tests deterministas verdes; indisponibilidades de fullscreen, MediaWidget y restauración exacta del cursor registradas explícitamente.

**Rollback:** Mismo que WU3 (revertir archivos). Los checks runtime no mutan estado persistente.

---

## Resumen de Dependencias

```
P0.1 (Git) ─────────────────────────────────────────────────────────┐
                                                                    │
P0.2 (test runner) ──┐                                              │
  [RESOLVED]          │                                              │
                      ▼                                              │
WU1: RED tests ──────► WU2: GREEN helper+singleton ─────────────────►│
                      (qmltestrunner)                                │
                              │                                      │
                              ▼                                      │
                     WU3: Migración atómica ─────────────────────────►│
                              │                                      │
                              ▼                                      │
                     WU4: Verificación estática+runtime ◄─────────────┘
                     (orchestrator acquires before WU4 actor launch)
```

## Límites Explícitos de Este Change

- No se modifica Hyprland, autostart, ni configuración externa.
- No se toca OSD, notificaciones, calendario, historial, DND.
- No se cambia identidad visual, animaciones, layout.
- No se incorpora C++ ni plugins nativos.
- Python se limita a contratos estructurales (source parsing); NO demuestra comportamiento del reducer.
- El comportamiento del reducer se verifica exclusivamente con Qt Quick Test (`qmltestrunner` + `tst_overlay_state.qml` que importa `Services/OverlayState.js`).
- `gentle-ai sdd-attempt acquire/settle` es orchestrator-owned; ningún actor de implementación los invoca.
- `gentle-ai sdd-attempt acquire` se ejecuta **antes** del primer actor `sdd-apply` con runtime bearing, después de resolver P0.1.

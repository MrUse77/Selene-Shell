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

**Apply readiness: Blocked by P0.1** (Git common directory not confirmed).

---

## Prerrequisitos Bloqueantes

Estos prerrequisitos deben resolverse antes de cualquier apply con runtime bearing.

- [ ] **P0.1 — Git common directory confirmado.** Verificar que `/home/agustin/Dev/Lab/QML` tiene un repositorio Git funcional (`.git/HEAD` legible o worktree con common-dir). Si no existe, el apply queda bloqueado hasta que se resuelva externamente. `gentle-ai sdd-attempt acquire` requiere Git. **Status: UNRESOLVED — blocks apply.**
- [x] **P0.2 — Test runner determinista confirmado.** `qmltestrunner` existe en `/usr/bin/qmltestrunner`. Soporta `-input` y `-import`. No soporta `--version` (confirmado). El comando determinista para tests del reducer es:
  ```
  QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/overlay-state -import .
  ```
  Import roots adicionales pueden agregarse si se descubren durante RED (ej. `-import Services`). `/usr/bin/qml` también está disponible como fallback.
- [ ] **P0.3 — `gentle-ai sdd-attempt acquire` disponible.** Una vez P0.1 esté resuelto, el orquestador adquiere token nativo **antes** de lanzar el primer actor `sdd-apply` con runtime bearing. Ningún actor inventa tokens ni request IDs. El orquestador llama `settle` después de la ejecución acotada del actor con evidencia real.

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

- [ ] **T1.1 — RED: Exclusividad global.** Test: dado estado cerrado, `open("launcher", {source:"widget", screen:screenA, explicit:true})` produce `{activeKind:"launcher", targetScreen:screenA}`. Luego `open("dashboard", {source:"widget", screen:screenB, explicit:true})` produce `{activeKind:"dashboard", targetScreen:screenB}` — launcher fue reemplazado.
- [ ] **T1.2 — RED: Open idempotente del mismo kind.** Test: dado launcher abierto en screenA, `open("launcher", {source:"ipc", screen:screenB, explicit:true})` NO cambia pantalla — conserva screenA. Retorna `accepted: true` sin mutar.
- [ ] **T1.3 — RED: Toggle cierra, doble toggle restaura.** Test: desde cerrado, `toggle("launcher", origen válido)` → abierto. Otro `toggle("launcher", origen válido)` → cerrado. Estado final: `{activeKind:"", targetScreen:null}`.
- [ ] **T1.4 — RED: Captura inmutable — cambio de foco no mueve.** Test: launcher abierto en screenA. Simular cambio de foco (la lista de screens no cambia, solo el foco). Consultar estado: `targetScreen` sigue siendo screenA. El reducer no recibe ni procesa eventos de foco.
- [ ] **T1.5 — RED: Cierre idempotente.** Test: desde estado cerrado, `close()` → `{activeKind:"", targetScreen:null}`, `accepted: true`. `close("launcher")` cuando launcher no está abierto → sin cambio, `accepted: true`.
- [ ] **T1.6 — RED: Origen con pantalla removida descartado.** Test: dado launcher abierto en screenA, screenA se remueve de la lista de screens vivas. `open("launcher", {source:"widget", screen:screenA, explicit:true})` → `accepted: false`, estado cerrado (el cierre por hotplug ya procesó).
- [ ] **T1.7 — RED: IPC con origen vigente durante hotplug.** Test: launcher abierto en screenA. screenA removida. `toggle("launcher", {source:"ipc", screen:screenB, explicit:true})` con screenB vigente → `accepted: true`, estado `{activeKind:"launcher", targetScreen:screenB}`.
- [ ] **T1.8 — RED: Widget con pantalla propietaria removida descartado.** Test: launcher abierto en screenA. screenA removida. `open("launcher", {source:"widget", screen:screenA, explicit:true})` → `accepted: false`, estado cerrado.
- [ ] **T1.9 — RED: Fallback sin pantallas.** Test: lista de screens vacía. `resolveFocusedScreen()` retorna `null`. `open` con screen null → `accepted: false`.
- [ ] **T1.10 — RED: Cierre por hotplug (closeForScreen).** Test: launcher abierto en screenA. `closeForScreen(screenA)` → cerrado. `closeForScreen(screenB)` (otra pantalla) → sin cambio.
- [ ] **T1.11 — RED: Policy fullscreen — pasivo rechazado, explícito aceptado.** Test: con bandera fullscreen activa en screenA, `open("launcher", {source:"passive", screen:screenA, explicit:false})` → `accepted: false`. `open("launcher", {source:"widget", screen:screenA, explicit:true})` → `accepted: true`.
- [ ] **T1.12 — RED: Secuencia rápida launcher→dashboard→power.** Test: desde cerrado, `open("launcher")`, `open("dashboard")`, `open("power")` en secuencia. Estado final: `{activeKind:"power", targetScreen:screenC}`. Exactamente uno abierto.
- [ ] **T1.13 — RED: Kind inválido descartado.** Test: `open("calendar", origen)` → `accepted: false`, estado sin cambio. Solo "launcher", "dashboard", "power" son válidos.

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

- [ ] **T2.1 — GREEN: Implementar `Services/OverlayState.js`.** Reducer puro que exporta `reduce(state, action, liveScreens)` y `resolveFocusedScreen(focusedName, liveScreens)`. Sin imports de Quickshell/Hyprland. Funciones puras: `open`, `toggle`, `close`, `closeForScreen`. Valida kind contra `["launcher","dashboard","power"]`. Valida screen contra `liveScreens`. Retorna `{state, accepted}`.
- [ ] **T2.2 — GREEN: Tests de WU1 pasan.** Ejecutar `QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/overlay-state -import .`. Todos los tests de T1.1–T1.13 pasan. Si algún test revela un edge case no contemplado en el diseño, documentar y ajustar el reducer sin cambiar el test (el test es la especificación).
- [ ] **T2.3 — Implementar `Services/OverlayCoordinator.qml`.** Singleton que importa `QtQuick`, `Quickshell`, `Quickshell.Hyprland`. Propiedades privadas: `_activeKind: ""`, `_targetScreen: null`. Propiedades readonly públicas: `activeKind`, `targetScreen`, `isOpen`, `launcherOpen`, `dashboardOpen`, `powerOpen`, `targetScreenName`. Funciones públicas: `open(kind, origin)`, `toggle(kind, origin)`, `close(kind)`, `closeForScreen(screen)`, `isScreenValid(screen)`, `resolveFocusedScreen()`. Cada función construye la acción, llama al reducer con `Quickshell.screens` como liveScreens, y publica el resultado. Observa cambios en `Quickshell.screens` para cierre por hotplug: si `_targetScreen` ya no pertenece a la lista, ejecuta `closeForScreen(_targetScreen)`.
- [ ] **T2.4 — Registrar singleton en `Services/qmldir`.** Agregar línea: `singleton OverlayCoordinator OverlayCoordinator.qml`. Verificar que el archivo parsea sin errores de sintaxis QML.
- [ ] **T2.5 — Verificación estructural (Python).** Agregar a `tests/test_selene_corrections.py` o crear test nuevo: (a) `OverlayCoordinator.qml` existe y declara `_activeKind` y `_targetScreen` como propiedades asignables; (b) las proyecciones `activeKind`, `targetScreen`, `launcherOpen`, `dashboardOpen`, `powerOpen` son `readonly`; (c) `qmldir` contiene `singleton OverlayCoordinator`.

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

- [ ] **T3.1 — Migrar `shell.qml` IPC handlers.** Los tres handlers `toggleLauncher/toggleDashboard/togglePower` ahora: (1) llaman `OverlayCoordinator.resolveFocusedScreen()` para capturar monitor enfocado en el instante; (2) construyen `origin = {source:"ipc", screen:resolved, explicit:true}`; (3) llaman `OverlayCoordinator.toggle(kind, origin)`. Los handlers de calendar/history/DND/calc quedan intactos con `ShellState`.
- [ ] **T3.2 — Migrar `Modules/Launcher/Launcher.qml`.** Eliminar `readonly property var targetScreen` reactivo basado en `Hyprland.focusedMonitor`. Reemplazar: `screen: OverlayCoordinator.targetScreen`, `visible: OverlayCoordinator.launcherOpen`, `focusable: OverlayCoordinator.launcherOpen`. Función `close()` llama `OverlayCoordinator.close("launcher")`. Preservar WlrLayer.Overlay, ExclusionMode.Ignore, anclajes, colores, animaciones.
- [ ] **T3.3 — Migrar `Modules/Dashboard/Dashboard.qml`.** Mismo patrón: eliminar `targetScreen` reactivo. `screen: OverlayCoordinator.targetScreen`, `visible: OverlayCoordinator.dashboardOpen`, `focusable: OverlayCoordinator.dashboardOpen`. Preservar layout, margins, Mpris, Bluetooth, DND (DND sigue en ShellState).
- [ ] **T3.4 — Migrar `Modules/PowerMenu/PowerMenu.qml`.** Mismo patrón: eliminar `targetScreen` reactivo. `screen: OverlayCoordinator.targetScreen`, `visible: OverlayCoordinator.powerOpen`, `focusable: OverlayCoordinator.powerOpen`. `close()` llama `OverlayCoordinator.close("power")`. Preservar layout, colores, MouseArea de dismiss.
- [ ] **T3.5 — Migrar `Modules/Bar/Bar.qml`.** (a) `anyOverlay` lee `OverlayCoordinator.isOpen` en vez de los tres booleans de ShellState. (b) Indicador launcher: `active: OverlayCoordinator.launcherOpen`, `onClicked: OverlayCoordinator.toggle("launcher", {source:"widget", screen:root.modelData, explicit:true})`. (c) Indicador dashboard: `active: OverlayCoordinator.dashboardOpen`, `onClicked: OverlayCoordinator.toggle("dashboard", {source:"widget", screen:root.modelData, explicit:true})`. (d) Inyectar `screen: root.modelData` en `MediaWidget` y `PowerButton`.
- [ ] **T3.6 — Migrar `Modules/Bar/MediaWidget.qml`.** Declarar `property var screen: null`. En `onClicked`: `OverlayCoordinator.open("dashboard", {source:"widget", screen:root.screen, explicit:true})`. Eliminar asignación directa `ShellState.dashboardOpen = true`.
- [ ] **T3.7 — Migrar `Modules/Bar/PowerButton.qml`.** Declarar `property var screen: null`. `active: OverlayCoordinator.powerOpen`. `onClicked: OverlayCoordinator.toggle("power", {source:"widget", screen:root.screen, explicit:true})`.
- [ ] **T3.8 — Retirar estados de `Services/ShellState.qml`.** Eliminar: `property bool launcherOpen`, `property bool dashboardOpen`, `property bool powerOpen`, `function toggleLauncher()`, `function toggleDashboard()`, `function togglePower()`. Conservar intactos: calendarOpen/Screen, historyOpen/Screen, dnd, unread, history, historyCap, toggleCalendar, toggleHistory, addHistory, clearHistory, evalExpr.
- [ ] **T3.9 — Búsqueda dirigida: símbolos heredados eliminados.** Ejecutar grep en todo el proyecto confirmando CERO ocurrencias de: `ShellState.launcherOpen`, `ShellState.dashboardOpen`, `ShellState.powerOpen`, `ShellState.toggleLauncher`, `ShellState.toggleDashboard`, `ShellState.togglePower`. Si queda alguna, migrar antes de continuar.
- [ ] **T3.10 — Búsqueda dirigida: sin asignaciones prohibidas al coordinador.** Grep confirmando CERO asignaciones a `OverlayCoordinator._activeKind`, `OverlayCoordinator._targetScreen`, `OverlayCoordinator.activeKind`, `OverlayCoordinator.targetScreen` fuera de `OverlayCoordinator.qml`. Las proyecciones readonly impiden escritura, pero verificar que ningún consumidor intenta asignarlas.
- [ ] **T3.11 — Verificación estructural post-migración.** Extender tests Python: (a) `ShellState.qml` no declara `launcherOpen`, `dashboardOpen`, `powerOpen`, `toggleLauncher`, `toggleDashboard`, `togglePower`; (b) ningún archivo fuera de `OverlayCoordinator.qml` asigna a las propiedades privadas del coordinador; (c) `Launcher.qml`, `Dashboard.qml`, `PowerMenu.qml` leen `screen` de `OverlayCoordinator.targetScreen`; (d) `shell.qml` IPC usa `OverlayCoordinator.resolveFocusedScreen()` para los tres toggles.

**Verificación:** Todos los consumers migrados. ShellState sin los tres estados interactivos. Búsquedas dirigidas confirman ausencia de símbolos heredados. Tests estructurales pasan.

**Rollback:** Revertir los 8 archivos juntos. Restaura autoridad única de ShellState. Sin datos persistentes afectados.

---

## Work Unit 4: Verificación Estática y Runtime Acotado

**Objetivo:** Confirmar contratos estructurales y validar integración con dos monitores conectados.

**Precondición orchestrador:** Antes de lanzar el primer actor `sdd-apply` que ejecute este work unit, el orquestador debe haber llamado `gentle-ai sdd-attempt acquire` (P0.1 resuelto). El actor implementa; el orquestador liquida con `settle` al completar.

**Dependencias:** WU3 (migración completa).

- [ ] **T4.1 — Ejecutar tests deterministas completos.** Correr `QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/overlay-state -import .` (reducer) + tests estructurales Python extendidos (`pytest tests/test_selene_corrections.py` o equivalente). Todos pasan. Registrar comando exacto y resultado.
- [ ] **T4.2 — Runtime: apertura desde widgets de barra (2 monitores).** Con DP-2 y HDMI-A-1 conectados: (a) clic en botón launcher de barra DP-2 → launcher aparece en DP-2; (b) clic en botón dashboard de barra HDMI-A-1 → dashboard aparece en HDMI-A-1; (c) clic en MediaWidget de barra DP-2 → dashboard en DP-2; (d) clic en PowerButton de barra HDMI-A-1 → power en HDMI-A-1. Registrar monitor esperado vs observado.
- [ ] **T4.3 — Runtime: IPC con foco alternado.** (a) Foco en DP-2, `toggleLauncher` → launcher en DP-2; (b) mover foco a HDMI-A-1, launcher permanece en DP-2; (c) `toggleDashboard` con foco en HDMI-A-1 → dashboard en HDMI-A-1, launcher se cierra.
- [ ] **T4.4 — Runtime: reemplazo launcher→dashboard→power.** Abrir launcher (DP-2), luego dashboard (HDMI-A-1), luego power (DP-2). Confirmar que solo el último está abierto en cada paso.
- [ ] **T4.5 — Runtime: fullscreen con acción explícita.** Aplicación fullscreen en DP-2. Clic en widget launcher de barra DP-2 → launcher se abre sobre fullscreen.
- [ ] **T4.6 — Runtime: desconexión de pantalla capturada.** Launcher abierto en DP-2. Desconectar DP-2. Confirmar: launcher se cierra, no aparece en HDMI-A-1. Reconectar DP-2: ningún overlay abierto.
- [ ] **T4.7 — Limpieza post-runtime.** Restaurar estado: todos los overlays cerrados. Si se usó control transitorio de dunst para algún escenario, restaurar servicio. No usar `qs kill` innecesariamente; si se mató alguna instancia, documentar cuál y por qué. Verificar con `qs list --all --json` que el estado es limpio.
- [ ] **T4.8 — Verificación final de compatibilidad.** Confirmar: nombres IPC sin cambios (`toggleLauncher`, `toggleDashboard`, `togglePower`), calendario e historial funcionan como antes, OSD y notificaciones sin cambios visuales, identidad visual de overlays preservada.

**Verificación:** Todos los escenarios runtime documentados con resultado esperado = observado. Tests deterministas verdes.

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

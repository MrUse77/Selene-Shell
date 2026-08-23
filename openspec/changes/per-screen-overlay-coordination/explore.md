# Exploración: coordinación de overlays por pantalla en Selene

Hoy Selene abre launcher, dashboard, notificaciones, OSD y power como overlays globales que resuelven su pantalla objetivo a partir del monitor enfocado de Hyprland en cada instante. Eso hace que un overlay pueda saltar de monitor si el foco cambia mientras está abierto, y que no sea posible tener estados independientes por pantalla. Esta exploración mapea el estado actual, contrasta patrones de arquitectura sin elegir aún ninguno, y delinea las decisiones de producto que la proposal debe resolver.

## Resumen ejecutivo

- El estado de overlays vive casi todo en `Services/ShellState.qml` como booleanos globales (`launcherOpen`, `dashboardOpen`, `powerOpen`). Solo calendario e historial de notificaciones ya usan un modelo por pantalla (`calendarOpen` + `calendarScreen`, `historyOpen` + `historyScreen`).
- Los overlays globales resuelven `targetScreen` reactivamente con `Hyprland.focusedMonitor?.name`, por lo que siguen el foco en vez de capturar la pantalla en el momento de abrirse.
- El OSD no tiene política de pantalla: no declara `screen`, así que Quickshell lo coloca en la pantalla por defecto.
- Las notificaciones se muestran en una sola ventana global anclada al monitor enfocado; no hay ruteo por urgencia ni por pantalla de origen.
- El patrón más prometedor para este tamaño es un **coordinador singleton con slots por pantalla** que capture la pantalla objetivo al abrir, reemplace los booleanos globales y centralice exclusividad y cierre. No justifica un plugin nativo de C++.

## Ruta rápida para revisar esta exploración

1. Leer el mapeo de estado actual (sección siguiente).
2. Contrastar los cuatro patrones arquitectónicos y sus trade-offs.
3. Revisar las decisiones de producto pendientes; la proposal debe preguntarlas explícitamente.
4. Ver los límites propuestos para mantener el primer slice bajo ~400 líneas cambiadas.

## Estado actual de la coordinación

### Propiedad del estado

| Estado | ¿Dónde vive? | ¿Por pantalla? | Rutas / símbolos clave |
|--------|--------------|----------------|------------------------|
| `launcherOpen` | `Services/ShellState.qml:11` | No | `Modules/Launcher/Launcher.qml` usa `ShellState.launcherOpen` para `visible` y `focusable` |
| `dashboardOpen` | `Services/ShellState.qml:12` | No | `Modules/Dashboard/Dashboard.qml:38`, `Modules/Bar/MediaWidget.qml:47` |
| `powerOpen` | `Services/ShellState.qml:13` | No | `Modules/PowerMenu/PowerMenu.qml:29`, `Modules/Bar/PowerButton.qml:9` |
| `calendarOpen` + `calendarScreen` | `Services/ShellState.qml:16-19` | Sí | `Modules/Bar/ClockWidget.qml`, `Modules/Bar/CalendarPopup.qml` |
| `historyOpen` + `historyScreen` | `Services/ShellState.qml:20-23` | Sí | `Modules/Bar/NotifsWidget.qml`, `Modules/Bar/HistoryPopup.qml` |
| DND + historial + unread | `Services/ShellState.qml:25-28` | No | `Modules/Notifications/Notifications.qml`, `Modules/Dashboard/Dashboard.qml:232` |

### Cómo se elige la pantalla objetivo

| Overlay | Cómo resuelve la pantalla | Fuente |
|---------|---------------------------|--------|
| Barra, CalendarPopup, HistoryPopup | `modelData` desde `Variants { model: Quickshell.screens }` | `shell.qml:20-32` |
| Launcher | `Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)` con fallback a `Quickshell.screens[0]` | `Modules/Launcher/Launcher.qml:20-23` |
| Dashboard | Igual que Launcher | `Modules/Dashboard/Dashboard.qml:20-25` |
| PowerMenu | Igual que Launcher | `Modules/PowerMenu/PowerMenu.qml:18-21` |
| Notifications | Igual que Launcher | `Modules/Notifications/Notifications.qml:22-25` |
| OSD | No resuelve pantalla; falta propiedad `screen` | `Modules/Osd/Osd.qml:8-26` |

### Puntos de entrada IPC

Todos están en `shell.qml:50-62`:

- `toggleLauncher()` → `ShellState.toggleLauncher()`
- `toggleDashboard()` → `ShellState.toggleDashboard()`
- `togglePower()` → `ShellState.togglePower()`
- `toggleCalendar()` → usa `Hyprland.focusedMonitor?.name`
- `toggleHistory()` → usa `Hyprland.focusedMonitor?.name`

### Ciclo de vida y foco

- Todos los overlays usan `WlrLayershell.layer: WlrLayer.Overlay` y `exclusionMode: ExclusionMode.Ignore`.
- Launcher, Dashboard y PowerMenu son superficies a pantalla completa con `MouseArea` que cierra al hacer clic fuera del contenido y `Keys.onEscapePressed`.
- CalendarPopup y HistoryPopup usan `HyprlandFocusGrab { active: root.visible; onCleared: ... }` para cerrar al perder foco.
- Launcher, Dashboard y PowerMenu usan `focusable: ShellState.*Open` para poder dibujarse por encima de ventanas fullscreen.

### Interacciones entre overlays

- `Modules/Bar/Bar.qml:27` enciende el borde de acento si `launcherOpen || dashboardOpen || powerOpen`; no considera calendar/history.
- `Modules/Bar/MediaWidget.qml:47` abre el dashboard global (`ShellState.dashboardOpen = true`).
- DND y el historial de notificaciones son globales; cualquier popup de calendario/historial abre en una sola pantalla a la vez.

## Patrones arquitectónicos y trade-offs

### Patrón A: Estado por pantalla en `ShellState` (estilo Caelestia `forScreen`)

Reemplazar los booleanos globales por objetos de estado por pantalla (`ShellState.forScreen(screen).launcherOpen`).

- **Pros**: modelo limpio, escalable, alinea calendario/historial con el resto.
- **Contras**: cambio amplio en `ShellState.qml` y en todos los consumidores; las transiciones globales (IPC sin pantalla) requieren resolver una pantalla objetivo antes de tocar el estado.
- **Adecuación**: buena si la visión a largo plazo es que cada pantalla sea independiente.

### Patrón B: Coordinador singleton con slots por pantalla (recomendado para explorar)

Crear un `OverlayCoordinator` que exponga slots por pantalla (`launcherScreen`, `dashboardScreen`, `powerScreen`) y funciones `toggleLauncher(screen?)`. Los módulos leen de ahí.

- **Pros**: captura la pantalla objetivo en el momento de abrir; centraliza exclusividad y cierre transitorio; el cambio en consumidores es menor que en A.
- **Contras**: introduce una nueva abstracción; hay que decidir si mantiene compatibilidad con `ShellState` o lo reemplaza.
- **Adecuación**: equilibrio entre cambio controlado y modelo robusto para ~2 monitores.

### Patrón C: Capturar pantalla pero conservar booleanos globales

Agregar `targetScreen` a cada overlay y capturarla al abrir, sin tocar `ShellState`.

- **Pros**: mínima invasión en el estado compartido.
- **Contras**: la lógica de exclusividad queda dispersa; IPC sigue sin saber en qué pantalla abrió; no resuelve el modelo a largo plazo.
- **Adecuación**: parche rápido, no una arquitectura.

### Patrón D: Plugin nativo de C++

Escribir un plugin que gestione ventanas y foco desde C++.

- **Pros**: control total sobre foco y layers.
- **Contras**: complejidad de build, distribución y mantenimiento; desproporcionado para el tamaño actual de Selene.
- **Adecuación**: descartado para el primer slice.

## Decisiones de producto pendientes

La proposal debe preguntar explícitamente al humano:

1. **Exclusividad de overlays**: ¿pueden coexistir launcher + dashboard? ¿launcher + power? ¿dashboard + power? Hoy técnicamente sí, pero no hay política.
2. **Semántica de pantalla objetivo**: ¿se captura la pantalla en el instante de abrir (recomendado), se sigue el foco reactivamente (comportamiento actual), o se abre en la pantalla del widget que disparó el evento?
3. **Comportamiento cross-monitor**: si un overlay está abierto en DP-2 y el foco pasa a HDMI-A-1, ¿el overlay se cierra, se mantiene en DP-2, o se duplica en HDMI-A-1?
4. **Fullscreen**: ¿los overlays siempre deben dibujarse por encima de ventanas fullscreen? ¿Incluso si eso les roba el foco a un juego?
5. **Ruteo del OSD**: ¿en qué monitor aparece? Opciones: monitor enfocado, monitor donde ocurrió el cambio de volumen (información que hoy no tenemos), monitor primario, o todos.
6. **Ruteo de notificaciones**: ¿en el monitor enfocado? ¿en el monitor donde está la ventana que emitió la notificación? ¿en ambos? ¿separa críticas del resto?
7. **Hotplug y fallback**: si se desconecta la pantalla donde estaba abierto un overlay, ¿se cierra, se mueve al monitor restante, o queda en un estado fantasma?

## Límites y no-objetivos para el primer slice

Para mantener la primera entrega revisable bajo ~400 líneas cambiadas:

- **Dentro del slice**: migrar launcher, dashboard y power a un modelo de pantalla capturada; introducir el coordinador; actualizar IPC y barra.
- **Fuera del primer slice (pero documentados)**: ruteo explícito de OSD, ruteo de notificaciones por pantalla, y hotplug avanzado.
- **No se hará**: plugin C++, rediseño visual, copiar visualmente a Caelestia, modificar `hyprland.lua`, autostart, dunst, waybar ni eww.

## Riesgos concretos

| Riesgo | Evidencia | Impacto |
|--------|-----------|---------|
| Overlay salta de monitor si cambia el foco | `Modules/Launcher/Launcher.qml:20` reevalúa `targetScreen` continuamente | Confusión de UX |
| OSD aparece en pantalla equivocada | `Modules/Osd/Osd.qml` no declara `screen` | Feedback de volumen en monitor incorrecto |
| Estado global impide independencia por monitor | `ShellState.launcherOpen` es único | Bloquea flujos multi-monitor naturales |
| Calendar/History puede quedar con `screenName` obsoleto | `ShellState.calendarScreen` es string, no referencia segura | Overlay huérfano tras hotplug |
| `focusable` sobre fullscreen interrumpe juegos | `Modules/Dashboard/Dashboard.qml:40-42` comenta la intención | Necesita política de producto |

## Checklist de lecturas verificadas

- [x] `shell.qml` monta barras/calendario/historial por pantalla y overlays globales.
- [x] `Services/ShellState.qml` contiene booleanos globales para launcher/dashboard/power.
- [x] Launcher, Dashboard y PowerMenu usan `Hyprland.focusedMonitor` para elegir pantalla.
- [x] Notifications y OSD no tienen política de pantalla explícita (OSD ni siquiera `screen`).
- [x] CalendarPopup y HistoryPopup ya usan el modelo por pantalla con `HyprlandFocusGrab`.
- [x] La identidad visual lunar y los tokens de animación deben preservarse; no se copiará Caelestia.

## Siguiente paso recomendado

`sdd-propose`: redactar la proposal con las decisiones de producto de la sección "Decisiones de producto pendientes" resueltas o planteadas al humano, y seleccionar el Patrón B (coordinador singleton con slots por pantalla) como dirección por defecto a menos que el humano prefiera otro.

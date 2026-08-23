# Diseño: coordinación de overlays interactivos por pantalla

## Decisión

Se incorporará `Services/OverlayCoordinator.qml` como singleton y **única autoridad escribible** para launcher, dashboard y menú de energía. El singleton capturará una `ShellScreen` válida al abrir, conservará esa referencia hasta cerrar y aplicará exclusividad global. `ShellState` dejará de contener o mutar los tres estados; seguirá siendo la autoridad sin cambios para calendario, historial, DND, OSD y notificaciones.

La solución mantiene `shell.qml` como punto fino de composición, no incorpora C++, no altera visuales ni animaciones, y no cambia los nombres IPC.

## Alcance y límites

| Incluido | Excluido explícitamente |
|---|---|
| Launcher, dashboard, power, sus widgets de barra e IPC | C++ o plugins nativos |
| Captura de pantalla, exclusividad, fullscreen y hotplug | Rediseño visual o de animaciones |
| Tests deterministas del reducer de estado y check runtime acotado | Ruteo de OSD/notificaciones |
| Migración de consumidores relacionados de `ShellState` | Migrar calendario, historial o DND |

## Arquitectura propuesta

### Singleton y registro

Agregar `singleton OverlayCoordinator OverlayCoordinator.qml` a `Services/qmldir`. El archivo importará `QtQuick`, `Quickshell` y `Quickshell.Hyprland`; no importará módulos de UI. Así, los módulos leen la coordinación pero no pueden convertirse en autoridades alternativas.

`ShellState.qml` elimina únicamente `launcherOpen`, `dashboardOpen`, `powerOpen` y sus tres toggles. Conserva `calendarOpen/calendarScreen`, `historyOpen/historyScreen`, `dnd`, `unread`, `history` y `evalExpr` tal como están. No habrá adaptadores bidireccionales ni booleanos espejo: esos adaptadores crearían una segunda autoridad escribible y una ventana de divergencia.

### Modelo de estado

La representación es un único slot global, no tres slots por pantalla:

```qml
// Estado de implementación: sólo OverlayCoordinator lo asigna.
property string _activeKind: "" // "", "launcher", "dashboard" o "power"
property var _targetScreen: null // ShellScreen capturada; null si _activeKind == ""

// Contrato de lectura para todos los consumidores.
readonly property string activeKind: _activeKind
readonly property var targetScreen: _targetScreen
readonly property bool isOpen: _activeKind !== ""
readonly property bool launcherOpen: _activeKind === "launcher"
readonly property bool dashboardOpen: _activeKind === "dashboard"
readonly property bool powerOpen: _activeKind === "power"
readonly property string targetScreenName: _targetScreen?.name ?? ""
```

`_activeKind` es el discriminante y `_targetScreen` es la referencia capturada. Ambos son detalles de implementación privados del singleton: aunque QML no impone privacidad léxica, ningún consumidor puede asignarlos. Los consumidores **DEBEN** llamar exclusivamente a `open`, `toggle`, `close` o `closeForScreen`; **NO DEBEN** asignar `_activeKind`, `_targetScreen`, `activeKind`, `targetScreen` ni los booleanos derivados. Las proyecciones públicas son `readonly`, por lo que el contrato de lectura es exigible por QML y cualquier intento de escribirlas falla.

La pareja válida es `(kind válido, ShellScreen vigente)` o `("", null)`. Un `string` con valores cerrados evita instanciar tipos QML sólo para transportar tres alternativas y mantiene las comparaciones de bindings simples. Las funciones del singleton validan el valor recibido; tipos desconocidos se descartan sin mutar estado y dejan una advertencia diagnóstica.

### API pública

La API propuesta recibe la pantalla ya resuelta y metadatos de origen. Las pantallas no se derivan por binding dentro del coordinador una vez abierto.

```qml
function open(kind, origin): bool
function toggle(kind, origin): bool
function close(kind = ""): bool
function closeForScreen(screen): bool
function isScreenValid(screen): bool
function resolveFocusedScreen(): var
```

`origin` es un objeto efímero con `{ source, screen, explicit }`:

| `source` | Construcción | `screen` | `explicit` |
|---|---|---|---|
| `widget` | Barra o widget propietario | la `ShellScreen` del componente | `true` |
| `ipc` | `shell.qml` al entrar al handler | monitor Hyprland resuelto inmediatamente o fallback | `true` |
| `internal` | Sólo invocación futura permitida explícitamente | `ShellScreen` capturada por el emisor | según contrato del emisor |
| `passive` | evento interno sin interacción directa | sólo una pantalla ya validada | `false` |

No se aceptan nombres de pantalla como sustituto de la referencia: una string no prueba que el origen siga vivo. La validación compara identidad de objeto contra `Quickshell.screens` y exige `screen?.name` no vacío. `isScreenValid` debe recorrer la lista vigente en el instante de la transición; no debe mantener un cache reactivo que pueda autorizar un objeto removido.

### Transiciones e idempotencia

| Estado actual | Operación válida | Estado resultante |
|---|---|---|
| cerrado | `open(k, origen válido)` | `(k, origen.screen)` |
| `k` abierto | `open(k, origen válido)` | sin cambio; conserva la pantalla originalmente capturada |
| `k` abierto | `toggle(k, origen válido)` | cerrado |
| otro abierto | `open/toggle(k, origen válido)` | reemplazo atómico lógico por `(k, origen.screen)` |
| cualquiera | `close()` | cerrado |
| `k` abierto | `close(k)` | cerrado |
| otro abierto | `close(k)` | sin cambio |
| cualquiera | origen o kind inválido | sin cambio, `false` |

Para el reemplazo no se asignarán tres booleanos. Sólo las funciones públicas del singleton actualizan `_activeKind` y `_targetScreen` en una única transición; no existe estado intermedio públicamente escribible. Los bindings de UI pueden observar un frame de cierre/apertura por sus animaciones existentes, pero nunca dos `visible: true` desde el modelo. `close` es idempotente. `open` del mismo kind es idempotente y, por requisito, no recoloca la ventana aunque llegue un origen distinto. Los toggles consecutivos se serializan en el orden de entrega QML: dos toggles válidos del mismo kind desde cerrado terminan cerrados.

## Flujo de orígenes y carrera con hotplug

### Regla aprobada

Cada solicitud se valida contra el conjunto de pantallas **vigente al procesarla**. Una solicitud originada en una pantalla removida falla cerrada; una solicitud nueva con origen válido puede abrir de forma determinista. Por tanto, hotplug no gana incondicionalmente: invalida sólo referencias obsoletas.

La desconexión se procesa mediante un manejador del singleton observando cambios de `Quickshell.screens` (o una reevaluación explícita de `targetScreen` ligada a esa lista únicamente para validar existencia, no para resolver destino). Si `targetScreen` deja de pertenecer a la lista actual, ejecuta `closeForScreen(targetScreen)`. No selecciona fallback y no migra la ventana.

```text
widget DP-2 / IPC ──> captura origin.screen ──> valida contra screens actuales
                                                    │
                                     inválida ──────┴──> no-op / false
                                                    │ válida
                                                    v
                              OverlayCoordinator.open/toggle(kind, origin)
                                                    │
                         target actual removido? ───┼──> cierre si corresponde
                                                    v
                                  único (kind, targetScreen) publicado
```

### IPC

En cada `IpcHandler.toggleLauncher/toggleDashboard/togglePower`, `shell.qml` llamará primero a `OverlayCoordinator.resolveFocusedScreen()`, que buscará la pantalla cuyo `name` coincida con `Hyprland.focusedMonitor?.name` en ese instante. Si no existe, usará fallback determinista: pantalla primaria si la API disponible la expone y es válida; de otro modo, la primera entrada vigente de `Quickshell.screens`; si no hay ninguna, devuelve `null`. El handler construye inmediatamente `{ source: "ipc", screen: resolved, explicit: true }` y llama al toggle correspondiente. No guarda `Hyprland.focusedMonitor` en una propiedad ni lo pasa a un binding: una variación de foco posterior no puede mover la ventana.

### Widgets e invocaciones internas

`Bar.qml` ya recibe `modelData` por cada variante. Sus botones de launcher y dashboard pasarán `root.modelData`. `MediaWidget` y `PowerButton` recibirán una propiedad `screen` desde `Bar.qml` y transmitirán esa misma referencia. Ningún widget consulta `Hyprland.focusedMonitor` para abrir estos overlays.

Los cierres por Escape, clic exterior, selección de aplicación y acciones equivalentes invocan `OverlayCoordinator.close("<kind>")`. Las llamadas internas futuras deben usar `source: "internal"` y una `screen` explícita. Las pasivas usan `source: "passive"`; el coordinador las rechaza para estos tres overlays cuando la política de fullscreen no permite apertura. En este slice no se añade ningún emisor pasivo ni se altera OSD/notificaciones.

## Ventanas, foco y fullscreen

`Launcher.qml`, `Dashboard.qml` y `PowerMenu.qml` sustituyen su `targetScreen` reactivo basado en `Hyprland.focusedMonitor` por:

```qml
screen: OverlayCoordinator.targetScreen
visible: OverlayCoordinator.<kind>Open
focusable: OverlayCoordinator.<kind>Open
```

Sus tamaños que dependen de `targetScreen` pasan a usar la referencia del coordinador. La referencia sólo cambia al abrir otro kind o al cerrar, nunca por foco. Se preservan `WlrLayer.Overlay`, `ExclusionMode.Ignore`, anclajes, márgenes, color, componentes, animaciones y el foco inicial existente. `focusable` permanece verdadero mientras el overlay explícito esté abierto, de modo que puede cubrir fullscreen; el permiso depende de `origin.explicit`, no de una relajación visual o de layer-shell.

Como los únicos disparadores migrados son clics y comandos IPC directos, todos son explícitos. El contrato de `open` rechaza `passive` cuando la pantalla objetivo tiene fullscreen, usando la consulta de Hyprland disponible en el momento de transición; si la API no puede establecerlo con certeza, falla cerrada para `passive`. No se bloquea una acción explícita por fullscreen. No se aplicará `HyprlandFocusGrab` a estos overlays: calendario e historial conservan su patrón actual, independiente del coordinador.

## Mapa de migración

| Archivo / consumidor | Cambio | Autoridad posterior |
|---|---|---|
| `Services/OverlayCoordinator.qml` | nuevo reducer, validación de origen, resolución IPC y cierre hotplug | coordinador |
| `Services/qmldir` | registra el singleton | registro QML |
| `Services/ShellState.qml` | retira sólo los tres booleans/toggles interactivos | conserva estados no relacionados |
| `shell.qml` | IPC captura monitor y llama al coordinador | coordinador para los tres IPC; ShellState para calendario/historial/DND/notifs |
| `Modules/Launcher/Launcher.qml` | `screen`, `visible`, `focusable`, `close` | coordinador |
| `Modules/Dashboard/Dashboard.qml` | `screen`, `visible`, `focusable` | coordinador; DND queda ShellState |
| `Modules/PowerMenu/PowerMenu.qml` | `screen`, `visible`, `focusable`, `close` | coordinador |
| `Modules/Bar/Bar.qml` | indicador, estados activos y clics; inyecta `modelData` a Media/Power | coordinador |
| `Modules/Bar/MediaWidget.qml` | declara `screen`; abre dashboard con origen widget | coordinador |
| `Modules/Bar/PowerButton.qml` | declara `screen`; activo/clic desde coordinador | coordinador |
| `ClockWidget`, `CalendarPopup`, `NotifsWidget`, `HistoryPopup` | sin modificación | ShellState existente |
| `Notifications.qml`, `Osd.qml` | sin modificación | fuera de alcance |

Antes de retirar propiedades de `ShellState`, la implementación debe comprobar con búsqueda dirigida que no queden lectores ni escritores de `launcherOpen`, `dashboardOpen`, `powerOpen`, `toggleLauncher`, `toggleDashboard` y `togglePower`. La migración se aplica como una unidad: no se deja una etapa en que `ShellState` y el coordinador sean ambos escribibles. Después de la migración, todos los consumidores sólo leen las proyecciones `readonly` del coordinador y solicitan cambios mediante `open`, `toggle`, `close` o `closeForScreen`; no asignan sus propiedades de respaldo privadas.

## Estrategia de pruebas

### Sección determinista RED/GREEN

El seam será un helper QML puro extraído junto al singleton, por ejemplo `Services/OverlayState.js`, que recibe un estado plano, lista de pantallas vivas, solicitud y bandera de fullscreen, y devuelve `{ state, accepted }`. No depende de `Quickshell`, `Hyprland`, `PanelWindow` ni del escritorio. `OverlayCoordinator.qml` es un adaptador mínimo: captura dependencias de runtime, llama al helper y publica el resultado.

Esto habilita pruebas QML/JS de transición (con `qmltestrunner` si está disponible en el entorno de aplicación) o una prueba Python que ejecute el runner; la tarea de aplicación debe confirmar el comando exacto antes de declararlo ejecutable. RED primero debe codificar: exclusividad, open idempotente, doble toggle, captura inmutable, cierre idempotente, origen removido descartado, IPC/widget vigente aceptado, fallback sin pantallas, cierre por hotplug y policy explícita/pasiva. GREEN implementa sólo el helper y el adaptador necesarios.

El actual `tests/test_selene_corrections.py` es una suite Python de regresiones estáticas y puede extenderse para contratos estructurales (singleton registrado, widgets pasan pantalla y ausencia de escrituras heredadas), pero no demuestra transiciones QML ni comportamiento de compositor. Esos contratos deben ser deterministas y exigir: (1) `OverlayCoordinator.qml` declara únicamente `_activeKind` y `_targetScreen` como propiedades asignables y expone `activeKind`, `targetScreen`, booleanos derivados y nombre como `readonly`; (2) fuera de `OverlayCoordinator.qml` no existe ninguna asignación a `OverlayCoordinator._activeKind`, `OverlayCoordinator._targetScreen`, `OverlayCoordinator.activeKind`, `OverlayCoordinator.targetScreen` ni a sus booleanos derivados; y (3) `ShellState.qml` no declara `launcherOpen`, `dashboardOpen`, `powerOpen`, `toggleLauncher`, `toggleDashboard` o `togglePower`, y ningún consumidor conserva lecturas, llamadas o asignaciones a esos símbolos. Las aserciones deben inspeccionar asignaciones y definiciones, no sólo menciones, para no rechazar las lecturas permitidas de las proyecciones públicas. `qmllint` sólo se ejecutará sobre archivos que su versión instalada pueda parsear: el diseño existente registra que `qmlformat` no parsea optional chaining (`?.`), y el lint histórico está acotado a `Moon.qml`; no se afirmará que un qmllint antiguo certifica archivos con optional chaining.

### Runtime acotado a dos monitores

Con DP-2 y HDMI-A-1 conectados, ejecutar manualmente: apertura desde cada botón de barra, cada IPC con foco alternado antes y después de abrir, reemplazo launcher→dashboard→power, fullscreen con acción explícita, y desconexión del monitor capturado. Registrar comandos, monitor esperado/observado y screenshots selectivos. Este check valida integración Quickshell/Hyprland y foco; no sustituye las pruebas deterministas.

## Rollout, rollback y fallos

| Situación | Comportamiento | Recuperación |
|---|---|---|
| Origen sin pantalla válida | no abre ni cambia overlay actual | diagnóstico; siguiente acción válida puede abrir |
| Sin monitor enfocado IPC | fallback determinista; si no hay pantallas, no-op | reintentar tras estabilizar hotplug |
| Target desconectado | cierre idempotente, sin migración | abrir desde un origen vigente |
| API fullscreen incierta para pasivo | fail closed para pasivo | no aplica a acciones explícitas migradas |
| Regresión de coordinación | revertir work unit completo | restaura `ShellState` y elimina singleton |

Rollout: primero agregar test RED, luego helper/coordinador y registro, después migrar todos los consumidores de la tabla como una única autoridad, y finalmente ejecutar checks estáticos y runtime. No modificar configuración Hyprland, autostart ni nombres IPC.

Rollback: revertir los archivos del work unit (`OverlayCoordinator`, `qmldir`, `ShellState`, `shell.qml`, tres overlays y widgets/barra afectados) juntos. No hay datos persistentes ni migración de usuario; una reversión parcial está prohibida porque reintroduciría autoridades divergentes.

## Forecast de entrega y prerrequisito

Forecast honesto: **330–390 líneas** (helper+tests 100–135, coordinador+registro 95–115, migración de ventanas/IPC/barra/widgets 120–140). Es viable como un único work unit bajo el presupuesto de 400 líneas sólo si las pruebas se mantienen focalizadas y no se introduce un harness nuevo grande. Si la API de detección fullscreen exige más de ~20 líneas de adaptación o el runner requiere infraestructura adicional, aplicar `ask-on-risk` antes de implementar y separar: (1) reducer+tests+singleton, (2) migración UI/IPC+runtime; no usar excepción silenciosa.

El directorio actual carece de metadatos Git. Antes de `sdd-apply`, se necesita un repositorio o worktree con Git common directory para que la autoridad nativa de intentos, review y entrega pueda adquirir y liquidar su ledger. Esta fase no inicializa Git ni propone eludir ese requisito; hasta resolverlo, la aplicación/entrega queda bloqueada aunque el diseño esté completo.

## Riesgos pendientes

- La forma exacta de detectar fullscreen por pantalla debe verificarse contra la versión instalada de Quickshell/Hyprland; para invocaciones pasivas se conserva fail-closed.
- La disponibilidad de `qmltestrunner` no está documentada; el helper reduce el riesgo pero el comando definitivo se confirma antes de ejecutar.
- Hot reload puede recrear objetos QML; la validación por pertenencia a `Quickshell.screens` debe mantenerse como frontera de seguridad, no basarse sólo en nombre.
- La ausencia de Git bloquea los mecanismos nativos de intento/review/delivery hasta una decisión externa al change.

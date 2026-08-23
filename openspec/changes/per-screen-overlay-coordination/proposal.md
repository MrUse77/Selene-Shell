# Coordinar overlays interactivos por pantalla

Selene debe abrir launcher, dashboard y menú de energía en una pantalla determinada y mantenerlos allí durante toda su apertura. Este primer slice introduce una coordinación única en QML para evitar saltos entre monitores, superposiciones ambiguas y aperturas pasivas sobre fullscreen, sin cambiar la identidad visual ni los comandos IPC existentes.

## Intención

Hoy launcher, dashboard y menú de energía dependen de estado global y recalculan su pantalla a partir del monitor enfocado. Como consecuencia, un overlay abierto puede moverse cuando cambia el foco, varios overlays pueden quedar abiertos a la vez sin una política explícita y los disparadores no distinguen entre la pantalla de un widget y la pantalla enfocada para IPC.

El resultado buscado es una experiencia predecible:

- cada apertura captura una pantalla objetivo;
- solo uno de los tres overlays interactivos puede estar abierto globalmente;
- el overlay permanece en la pantalla capturada aunque cambie el foco;
- las acciones explícitas del usuario conservan la capacidad de interrumpir fullscreen, mientras que los eventos pasivos no abren estos overlays sobre fullscreen.

## Dirección propuesta

Introducir un **coordinador singleton en QML** como autoridad para launcher, dashboard y menú de energía. El coordinador centralizará la pantalla capturada, la exclusividad global y el cierre de los overlays. Los consumidores existentes migrarán de forma acotada hacia esa autoridad.

La propuesta no define todavía la API concreta, la representación interna del estado ni la secuencia exacta de migración; esas decisiones corresponden a especificación y diseño. No se incorporará un plugin de C++, porque agregaría complejidad de compilación, distribución y mantenimiento sin una necesidad proporcional en este slice.

## Alcance funcional

### Incluido

- Launcher, dashboard y menú de energía.
- Exclusividad global: como máximo uno de esos overlays puede estar abierto en cualquier momento.
- Aperturas originadas por widgets asociados a una pantalla: usan la pantalla propietaria del widget.
- Aperturas originadas por IPC: usan el monitor enfocado en el instante de la invocación.
- Captura de la pantalla objetivo al abrir; los cambios posteriores de foco no trasladan el overlay.
- Desconexión de la pantalla objetivo: se cierra el overlay afectado, sin migrarlo a otra pantalla.
- Apertura sobre fullscreen únicamente por una acción explícita del usuario.
- Adaptación de los consumidores de `ShellState` directamente relacionados con launcher, dashboard y menú de energía, incluida la indicación visual relevante de la barra.

### Consecuencias visibles para el usuario

- Un overlay deja de saltar entre monitores mientras está abierto.
- Abrir launcher, dashboard o menú de energía cierra cualquiera de los otros dos que estuviera abierto.
- Los controles de la barra abren el overlay en la pantalla donde se accionaron.
- Los comandos IPC abren el overlay en el monitor enfocado al ejecutarse y no siguen cambios de foco posteriores.
- Si se desconecta esa pantalla, el overlay desaparece en lugar de reaparecer en otro monitor.
- Un evento pasivo no debe cubrir una aplicación fullscreen con uno de estos overlays.

## Límites y no objetivos

- No se modifica el ruteo de OSD ni de notificaciones; ambos quedan explícitamente diferidos a slices posteriores.
- No se migran el calendario ni el historial de notificaciones. Su comportamiento y modelo actuales permanecen sin cambios en este slice.
- No se busca estado independiente que permita abrir simultáneamente estos overlays en distintas pantallas; la exclusividad es global.
- No se incorpora un plugin nativo de C++.
- No se rediseñan componentes, animaciones ni estilo visual.
- No se modifican integraciones externas no necesarias para esta coordinación, como configuración de Hyprland, autostart u otros shells y barras.
- No se define hotplug avanzado ni migración automática a otra pantalla.

## Compatibilidad

- Se preservan los nombres actuales de los comandos IPC y su propósito observable.
- Se preserva la identidad visual de Selene, incluidos sus patrones visuales y de animación, salvo que una especificación posterior autorice expresamente un cambio.
- Los usos heredados de `ShellState` no relacionados con los tres overlays quedan intactos.
- La migración de consumidores heredados relacionados debe evitar autoridades de estado duplicadas o divergentes. La compatibilidad transitoria, si fuera necesaria, deberá tener una única fuente de verdad y una retirada explícita.
- Calendario, historial, DND, OSD y notificaciones conservan su comportamiento vigente dentro de este slice.

## Áreas afectadas

| Área | Impacto esperado |
|------|------------------|
| Estado compartido QML | Nueva autoridad coordinadora y ajuste acotado de los estados heredados relacionados. |
| Launcher, dashboard y menú de energía | Lectura de visibilidad y pantalla desde la coordinación capturada. |
| Widgets de barra | Apertura dirigida a la pantalla propietaria del widget e indicador visual coherente. |
| IPC en `shell.qml` | Conservación de nombres y resolución de la pantalla enfocada al invocar. |
| Foco y fullscreen | Distinción entre aperturas explícitas y pasivas, sin seguimiento reactivo del foco. |
| Ciclo de vida de pantallas | Cierre seguro cuando desaparece la pantalla capturada. |

## Dependencias

- Identidad estable de las pantallas expuestas por Quickshell durante la vida del overlay.
- Fuente fiable del monitor enfocado de Hyprland en el momento de una invocación IPC.
- Señales de incorporación y desconexión de pantallas para cerrar estado capturado obsoleto.
- Semántica actual de foco y layershell de launcher, dashboard y menú de energía.
- Inventario completo de consumidores heredados de `ShellState` para evitar estados inconsistentes durante la migración.
- Presupuesto de revisión de 400 líneas cambiadas para mantener el slice verificable y cognitivamente manejable.

## Riesgos y mitigaciones propuestas

| Riesgo | Impacto | Mitigación en fases posteriores |
|--------|---------|-------------------------------|
| Hotplug deja una referencia de pantalla inválida | Overlay huérfano o errores de binding | Especificar cierre idempotente al desaparecer la pantalla capturada. |
| Foco cambia entre la intención y la apertura IPC | Apertura en un monitor inesperado | Resolver y capturar el monitor dentro de una única operación de apertura. |
| Detección ambigua de acción explícita frente a evento pasivo | Interrupción no deseada de fullscreen | Definir entradas autorizadas y política de fullscreen en la especificación. |
| Consumidores heredados siguen escribiendo `ShellState` | Dos fuentes de verdad y estados divergentes | Mapear consumidores y diseñar una transición con autoridad única. |
| Exclusividad incompleta en cierres o toggles rápidos | Dos overlays visibles o ninguno en estado coherente | Centralizar las transiciones en el coordinador y especificar invariantes. |
| El cambio supera 400 líneas | Fatiga de revisión y mayor riesgo de regresión | Mantener el slice restringido; si el diseño excede el presupuesto, proponer límites de entrega antes de aplicar. |
| Cambios visuales accidentales durante la migración | Pérdida de identidad o regresiones perceptibles | Tratar layout, estilo y animaciones actuales como compatibilidad obligatoria. |

## Rollback

La implementación deberá poder revertirse restaurando la autoridad previa de `ShellState` para launcher, dashboard y menú de energía y eliminando el coordinador QML y sus conexiones, sin migraciones persistentes de datos. Como este slice no cambia formatos almacenados ni nombres IPC, el rollback no debe requerir conversión de datos ni acciones del usuario.

## Criterios de éxito

La entrega posterior se considerará exitosa cuando exista evidencia de que:

- nunca hay más de uno entre launcher, dashboard y menú de energía abierto globalmente;
- una acción desde un widget abre el overlay en la pantalla de ese widget;
- una invocación IPC abre en el monitor enfocado en ese instante;
- cambiar el foco después de abrir no mueve el overlay;
- desconectar la pantalla capturada cierra el overlay sin migrarlo;
- los eventos pasivos no abren estos overlays sobre fullscreen y las acciones explícitas conservan esa capacidad;
- los nombres de comandos IPC y la identidad visual existente se mantienen;
- calendario, historial, OSD y notificaciones no cambian de comportamiento por este slice;
- no quedan autoridades divergentes entre el coordinador y consumidores heredados de `ShellState`;
- el alcance de entrega respeta el presupuesto de revisión de 400 líneas o presenta una decisión explícita antes de aplicar.

## Estado de esta fase

Esta propuesta documenta intención, alcance y dirección de producto. No afirma implementación ni verificación en runtime. La especificación y el diseño deberán convertir estas decisiones en requisitos comprobables y una arquitectura concreta antes de modificar producción.

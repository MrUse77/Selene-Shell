# overlay-coordination Specification

## Purpose
Definir el comportamiento normativo del coordinador de overlays interactivos de Selene para launcher, dashboard y menú de energía. El coordinador es la autoridad única que gestiona apertura, cierre, exclusividad global y resolución de pantalla objetivo de estos tres overlays.

## Requirements

### Requirement: Exclusividad Global

El sistema SHALL garantizar que, como máximo, uno entre launcher, dashboard y menú de energía puede estar abierto en cualquier instante durante la sesión.

#### Scenario: Apertura cierra overlay previo

- **WHEN** un overlay (por ejemplo, launcher) está abierto en la pantalla DP-2 y el usuario o IPC solicita abrir dashboard
- **THEN** launcher SHALL cerrarse completamente antes o durante la apertura de dashboard
- **THEN** dashboard SHALL aparecer como el único overlay interactivo visible

#### Scenario: Toggle del mismo overlay

- **WHEN** launcher está abierto y se invoca toggle launcher
- **THEN** launcher SHALL cerrarse
- **THEN** ningún overlay interactivo SHALL quedar abierto

#### Scenario: Apertura del mismo overlay ya abierto

- **WHEN** dashboard está abierto en HDMI-A-1 y se invoca open dashboard (no toggle)
- **THEN** dashboard SHALL permanecer abierto en HDMI-A-1 sin duplicarse ni moverse

#### Scenario: Idempotencia de cierre

- **WHEN** ningún overlay interactivo está abierto y se invoca close para cualquiera de los tres overlays
- **THEN** el estado SHALL permanecer sin overlays abiertos, sin errores ni efectos secundarios observables

### Requirement: Captura de Pantalla Objetivo

El sistema SHALL capturar la pantalla objetivo en el instante de apertura y mantener el overlay en esa pantalla durante toda su vida útil.

#### Scenario: Captura en apertura por widget

- **WHEN** un widget de barra en la pantalla DP-2 invoca la apertura de launcher y se abre launcher
- **THEN** launcher SHALL aparecer en DP-2
- **THEN** launcher SHALL permanecer en DP-2 aunque el foco cambie a HDMI-A-1

#### Scenario: Captura en apertura por IPC

- **WHEN** el monitor enfocado en Hyprland es HDMI-A-1 en el instante de invocación y se ejecuta el comando IPC `toggleLauncher`
- **THEN** launcher SHALL abrirse en HDMI-A-1
- **THEN** launcher SHALL permanecer en HDMI-A-1 aunque el foco cambie posteriormente

#### Scenario: Cambio de foco posterior no mueve el overlay

- **WHEN** launcher está abierto y capturado en DP-2 y el usuario mueve el foco a HDMI-A-1
- **THEN** launcher SHALL permanecer visible en DP-2
- **THEN** ningún binding reactivo SHALL reevaluar la pantalla objetivo del overlay abierto

### Requirement: Resolución de Pantalla para Widgets

El sistema SHALL abrir el overlay en la pantalla propietaria del widget que originó la apertura.

#### Scenario: Widget de barra en pantalla específica

- **WHEN** un MediaWidget en la barra de DP-2 invoca la apertura de dashboard y se abre dashboard
- **THEN** dashboard SHALL aparecer en DP-2, independientemente del monitor enfocado

#### Scenario: PowerButton en pantalla específica

- **WHEN** un PowerButton en la barra de HDMI-A-1 invoca la apertura del menú de energía y se abre el menú de energía
- **THEN** el menú de energía SHALL aparecer en HDMI-A-1

### Requirement: Resolución de Pantalla para IPC

El sistema SHALL resolver la pantalla objetivo de una invocación IPC usando el monitor enfocado de Hyprland en el instante exacto de la invocación.

#### Scenario: IPC con monitor enfocado válido

- **WHEN** Hyprland reporta HDMI-A-1 como monitor enfocado y se ejecuta `toggleDashboard` vía IPC
- **THEN** dashboard SHALL abrirse en HDMI-A-1

#### Scenario: IPC sin monitor enfocado identificable

- **WHEN** Hyprland no reporta un monitor enfocado válido (por ejemplo, durante una transición de hotplug) y se ejecuta un comando IPC de overlay
- **THEN** el sistema SHALL usar una pantalla de fallback determinista (pantalla primaria o primera pantalla disponible)
- **THEN** el overlay SHALL abrirse en esa pantalla de fallback capturada

### Requirement: Cierre por Desconexión de Pantalla

El sistema SHALL cerrar el overlay cuando la pantalla capturada donde reside se desconecta. El overlay SHALL NOT migrarse a otra pantalla.

#### Scenario: Desconexión de pantalla con overlay abierto

- **WHEN** launcher está abierto y capturado en DP-2 y DP-2 se desconecta (hotplug)
- **THEN** launcher SHALL cerrarse completamente
- **THEN** ningún overlay interactivo SHALL quedar abierto
- **THEN** ningún overlay fantasma SHALL aparecer en HDMI-A-1

#### Scenario: Desconexión de pantalla sin overlay abierto

- **WHEN** ningún overlay interactivo está abierto en DP-2 y DP-2 se desconecta
- **THEN** el sistema SHALL permanecer en estado sin overlays, sin errores

#### Scenario: Cierre idempotente por hotplug

- **WHEN** launcher está abierto en DP-2 y DP-2 se desconecta, y la señal de desconexión se emite múltiples veces o de forma repetida
- **THEN** el cierre SHALL ser idempotente: la primera desconexión cierra el overlay, las subsecuentes no producen errores ni efectos observables

### Requirement: Política de Fullscreen

El sistema SHALL distinguir entre aperturas originadas por acción explícita del usuario y eventos pasivos al decidir si un overlay puede abrirse sobre una ventana fullscreen.

#### Scenario: Acción explícita abre sobre fullscreen

- **WHEN** una aplicación está en modo fullscreen en DP-2 y el usuario realiza una acción explícita (clic en widget de barra, atajo de teclado configurado) para abrir launcher
- **THEN** launcher SHALL abrirse sobre la aplicación fullscreen

#### Scenario: Evento pasivo no abre sobre fullscreen

- **WHEN** una aplicación está en modo fullscreen en DP-2 y ocurre un evento pasivo (por ejemplo, una notificación, un cambio de volumen que dispara OSD)
- **THEN** ninguno de los tres overlays interactivos (launcher, dashboard, menú de energía) SHALL abrirse sobre la aplicación fullscreen como consecuencia de ese evento pasivo

#### Scenario: Definición observable de acción explícita

- **WHEN** se evalúa si una apertura es explícita o pasiva
- **THEN** la fuente de la invocación SHALL ser trazable a una interacción directa del usuario (clic en widget, atajo de teclado) o a una invocación IPC directa
- **THEN** los eventos generados internamente por el sistema sin interacción usuario-origen SHALL ser considerados pasivos

### Requirement: Compatibilidad IPC

El sistema SHALL preservar los nombres de comandos IPC existentes y su propósito observable.

#### Scenario: Nombres de comandos preservados

- **WHEN** los comandos IPC actuales son `toggleLauncher`, `toggleDashboard` y `togglePower` y se invoca cualquiera de estos comandos
- **THEN** el comando SHALL seguir existiendo con el mismo nombre y semántica observable (toggle del overlay correspondiente)

#### Scenario: Toggle IPC captura pantalla enfocada

- **WHEN** el monitor enfocado es DP-2 y se ejecuta `toggleLauncher` vía IPC
- **THEN** si launcher estaba cerrado, SHALL abrirse en DP-2
- **THEN** si launcher estaba abierto, SHALL cerrarse

### Requirement: Compatibilidad Visual

El sistema SHALL preservar la identidad visual existente de Selene, incluyendo patrones visuales, animaciones y estilo de launcher, dashboard y menú de energía.

#### Scenario: Identidad visual sin cambios

- **WHEN** se implementa la coordinación de overlays sobre la apariencia actual de launcher, dashboard y menú de energía
- **THEN** la apariencia visual, animaciones, layout y estilo SHALL permanecer idénticos
- **THEN** ningún cambio visual SHALL ser perceptible como consecuencia de la migración al coordinador

### Requirement: Migración de ShellState

El sistema SHALL mantener una única fuente de verdad para el estado de los tres overlays interactivos. Los consumidores heredados de `ShellState` relacionados con launcher, dashboard y menú de energía SHALL migrar al coordinador sin dejar autoridades de estado divergentes.

#### Scenario: Única fuente de verdad

- **WHEN** el coordinador es la autoridad para launcher, dashboard y menú de energía y cualquier consumidor consulta si un overlay está abierto
- **THEN** la consulta SHALL resolverse desde el coordinador, no desde booleanos globales heredados en `ShellState`

#### Scenario: Indicador visual de barra coherente

- **WHEN** el coordinador gestiona la visibilidad de los overlays y launcher, dashboard o menú de energía están abiertos
- **THEN** el indicador visual de acento en la barra SHALL reflejar correctamente el estado desde el coordinador

#### Scenario: Consumidores no relacionados intactos

- **WHEN** se migra launcher, dashboard y menú de energía al coordinador, dado que `ShellState` también gestiona calendario, historial, DND y notificaciones
- **THEN** el estado de calendario, historial, DND y notificaciones SHALL NOT ser afectado
- **THEN** los consumidores de esos estados SHALL NOT requerir cambios

### Requirement: Módulos Fuera de Alcance

El sistema SHALL NOT modificar el comportamiento de OSD, notificaciones, calendario ni historial de notificaciones como consecuencia de este cambio.

#### Scenario: OSD sin cambios

- **WHEN** se implementa la coordinación de overlays sobre el comportamiento actual de OSD
- **THEN** OSD SHALL mantener su comportamiento actual de pantalla y visibilidad

#### Scenario: Notificaciones sin cambios

- **WHEN** se implementa la coordinación de overlays sobre el comportamiento actual de notificaciones
- **THEN** las notificaciones SHALL mantener su comportamiento actual de ruteo y visibilidad

#### Scenario: Calendario e historial sin cambios

- **WHEN** se implementa la coordinación de overlays, dado que calendario e historial ya usan un modelo por pantalla (`calendarScreen`, `historyScreen`)
- **THEN** calendario e historial SHALL mantener su modelo y comportamiento actuales sin migrar al coordinador

### Requirement: Invariantes de Estado

El sistema SHALL mantener las siguientes invariantes en todo momento:

1. Si un overlay interactivo está abierto, exactamente uno está abierto (no cero por inconsistencia, no más de uno).
2. Si un overlay está abierto, tiene una pantalla objetivo capturada válida.
3. Si la pantalla objetivo capturada deja de existir, el overlay asociado está cerrado.
4. No existen bindings reactivos que reevalúen la pantalla objetivo de un overlay abierto.

#### Scenario: Invariante de exclusividad tras secuencia rápida

- **WHEN** ningún overlay está abierto y el usuario alterna rápidamente launcher → dashboard → power en sucesión rápida
- **THEN** al finalizar la secuencia, exactamente un overlay SHALL estar abierto (el último de la cadena)
- **THEN** no SHALL haber un estado intermedio donde dos overlays sean visibles simultáneamente de forma persistente

#### Scenario: Invariante de pantalla capturada

- **WHEN** launcher está abierto en DP-2 y se consulta el estado del coordinador
- **THEN** el coordinador SHALL reportar que launcher está abierto Y que su pantalla objetivo es DP-2

#### Scenario: Invariante post-hotplug

- **WHEN** launcher está abierto en DP-2 y DP-2 se desconecta y se consulta el estado inmediatamente después
- **THEN** el coordinador SHALL reportar que ningún overlay interactivo está abierto

### Requirement: Tolerancia a Condiciones de Carrera

El sistema SHALL manejar toggles y switches rápidos de forma que el estado final sea coherente y determinista, validando el origen de cada invocación. Durante un evento de hotplug, las invocaciones ligadas a una pantalla removida SHALL ser descartadas, mientras que las invocaciones con origen vigente SHALL resolverse de forma determinista. El sistema SHALL NOT imponer una regla incondicional de "hotplug siempre gana" ni depender del orden arbitrario de procesamiento.

#### Scenario: Toggle rápido del mismo overlay

- **WHEN** launcher está cerrado y se invocan dos toggles de launcher en rápida sucesión
- **THEN** el estado final SHALL ser launcher cerrado (toggle + toggle = cerrado)

#### Scenario: Switch rápido entre overlays

- **WHEN** launcher está abierto y se invocan rápidamente open dashboard y luego open power
- **THEN** el estado final SHALL ser power abierto como único overlay
- **THEN** launcher y dashboard SHALL estar cerrados

#### Scenario: Invocación con origen en pantalla removida durante hotplug

- **WHEN** launcher está abierto en DP-2 y DP-2 se desconecta y se recibe un evento de toggle cuyo origen está ligado a DP-2 (por ejemplo, un widget o screen source de DP-2)
- **THEN** el evento SHALL ser descartado por tener un origen inválido (pantalla removida)
- **THEN** launcher SHALL permanecer cerrado como resultado del cierre por hotplug
- **THEN** ningún overlay SHALL abrirse como resultado de ese evento descartado

#### Scenario: Invocación IPC válida durante hotplug

- **WHEN** launcher está abierto en DP-2 y DP-2 se desconecta y simultáneamente se recibe una invocación IPC de toggle launcher
- **THEN** el cierre por hotplug SHALL procesarse para DP-2
- **THEN** la invocación IPC SHALL resolverse contra el monitor enfocado o fallback vigente en ese instante
- **THEN** si la pantalla resuelta por IPC es válida y distinta de DP-2, launcher SHALL abrirse en esa pantalla resuelta
- **THEN** si ninguna pantalla válida está disponible, launcher SHALL permanecer cerrado

#### Scenario: Invocación de widget con pantalla propietaria vigente durante hotplug

- **WHEN** launcher está abierto en DP-2 y DP-2 se desconecta y simultáneamente un widget en HDMI-A-1 invoca open launcher
- **THEN** el cierre por hotplug SHALL procesarse para DP-2
- **THEN** la invocación del widget SHALL validar que HDMI-A-1 (su pantalla propietaria) aún existe
- **THEN** launcher SHALL abrirse en HDMI-A-1

#### Scenario: Invocación de widget con pantalla propietaria removida durante hotplug

- **WHEN** launcher está abierto en DP-2 y DP-2 se desconecta y simultáneamente un widget que pertenecía a DP-2 invoca open launcher
- **THEN** el evento SHALL ser descartado porque la pantalla propietaria del widget (DP-2) ya no existe
- **THEN** launcher SHALL permanecer cerrado como resultado del cierre por hotplug

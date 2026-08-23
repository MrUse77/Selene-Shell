# bar

## Purpose

La barra de Selene: una superficie continua por monitor con workspaces del compositor, estado del sistema y accesos a los overlays, siguiendo la identidad visual lunar de la shell. Los overlays (dashboard, OSD, etc.) flotan SIN zona exclusiva, superponiéndose a las ventanas.

## Requirements

### Requirement: Una barra por monitor
El sistema SHALL mostrar una barra independiente en cada monitor activo, creada y eliminada automáticamente al conectar/desconectar monitores, usando el tema derivado de moonarch.

#### Scenario: Dos monitores conectados
- **WHEN** hay dos monitores activos en Hyprland
- **THEN** cada monitor muestra su propia barra con contenido independiente por pantalla

### Requirement: Workspaces por monitor (SMW-aware)
El sistema SHALL mostrar los workspaces asignados al monitor de la barra (esquema split-monitor-workspaces, 5 por monitor), permitiendo enfocarlos con un clic, marcando el workspace activo con un indicador que se desliza entre posiciones, y distinguiendo visualmente el monitor enfocado.

#### Scenario: Clic en workspace
- **WHEN** el usuario hace clic en el workspace 3 de la barra
- **THEN** Hyprland enfoca ese workspace en ese monitor

#### Scenario: Cambio de workspace activo
- **WHEN** el workspace activo del monitor pasa de 2 a 4
- **THEN** el indicador se desliza de la posición 2 a la 4 con la animación configurada, sin teleport

### Requirement: Título de la ventana enfocada
El sistema SHALL mostrar el título de la ventana enfocada del monitor, actualizándose en vivo, con elipsis cuando exceda el ancho disponible.

#### Scenario: Cambio de foco
- **WHEN** el foco pasa a otra ventana con otro título
- **THEN** el texto mostrado se actualiza sin intervención del usuario

### Requirement: Reloj con fase lunar y calendario
El sistema SHALL mostrar la hora y la fase lunar actual (calculada astronómicamente), y al hacer clic abrir un calendario mensual navegable donde el día actual y fines de semana se distinguen con los colores del tema.

#### Scenario: Calendario
- **WHEN** el usuario hace clic en el reloj
- **THEN** se muestra un popup con el calendario del mes actual y el día de hoy resaltado

### Requirement: Indicadores de estado del sistema
El sistema SHALL mostrar en la barra: volumen del sink por defecto con estado de mute (clic abre el mezclador), uso de CPU y RAM con cambio de color al superar umbrales, contador de actualizaciones pendientes (pacman + AUR) visible solo cuando hay pendientes, bandeja del sistema con acceso a sus menús, y un chip de medios cuando hay reproducción activa.

#### Scenario: CPU en alerta
- **WHEN** el uso de CPU supera el umbral alto configurado
- **THEN** el indicador de CPU cambia al color de alerta del tema

#### Scenario: Updates pendientes
- **WHEN** hay 5 actualizaciones pendientes y ninguna antes
- **THEN** aparece el contador con el número 5 en la barra

### Requirement: Acceso a overlays desde la barra
El sistema SHALL proveer botones en la barra que abran/cierren el launcher, el dashboard y el menú de sesión.

#### Scenario: Abrir dashboard
- **WHEN** el usuario hace clic en el botón de dashboard de la barra
- **THEN** el dashboard se abre como overlay sobre ese monitor

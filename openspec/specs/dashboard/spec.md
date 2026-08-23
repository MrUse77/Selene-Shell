# dashboard

## Purpose

Panel de control de Selene en grilla bento: identidad del usuario, toggles rápidos, control de volumen, gauges de recursos, reproductor de medios y acciones de sesión, todo con la paleta derivada de moonarch.

## Requirements

### Requirement: Panel bento con identidad
El sistema SHALL mostrar un panel en grilla de dos columnas con: bloque de usuario (nombre, uptime, fase lunar), y controles organizados en tarjetas, abierto como overlay en el monitor enfocado desde la barra o IPC.

#### Scenario: Apertura
- **WHEN** el usuario abre el dashboard
- **THEN** se muestran las tarjetas de usuario, toggles, volumen, recursos, medios y sesión con el tema activo

### Requirement: Control de volumen del sink por defecto
El sistema SHALL permitir ajustar el volumen y mute del sink de audio por defecto desde el dashboard, reflejando en vivo cambios hechos por otras vías (teclas, mezclador).

#### Scenario: Ajuste externo reflejado
- **WHEN** el volumen cambia con las teclas de volumen mientras el dashboard está abierto
- **THEN** el slider del dashboard se mueve al nuevo valor

### Requirement: Gauges de recursos en vivo
El sistema SHALL mostrar medidores circulares de CPU, RAM y disco con muestreo periódico ligero, con colores de alerta del tema al superar umbrales.

#### Scenario: Lectura de recursos
- **WHEN** el dashboard está abierto
- **THEN** los gauges muestran valores actuales que se actualizan periódicamente

### Requirement: Reproductor de medios MPRIS
El sistema SHALL mostrar el reproductor MPRIS activo con título, artista, posición, arte cuando esté disponible y controles de previa/siguiente/play-pausa; con selección cuando hay varios jugadores.

#### Scenario: Reproducción activa
- **WHEN** hay un reproductor MPRIS reproduciendo
- **THEN** el dashboard muestra título, artista y posición avanzando, y los controles operan sobre el reproductor

#### Scenario: Sin reproducción
- **WHEN** no hay ningún reproductor MPRIS activo
- **THEN** la tarjeta de medios muestra un estado vacío elegante sin errores

### Requirement: Toggles rápidos
El sistema SHALL proveer toggles de bluetooth (encendido/apagado del adaptador) y de no-molestar (integrado con el módulo de notificaciones), con estado reflejado en vivo.

#### Scenario: Toggle de bluetooth
- **WHEN** el usuario activa el toggle de bluetooth
- **THEN** el adaptador bluetooth se enciende y el toggle refleja el nuevo estado

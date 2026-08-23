# osd

## Purpose

OSD (visualización en pantalla) de Selene para cambios de volumen, reactivo al estado real de PipeWire y con auto-ocultado, independiente de qué control disparó el cambio.

## ADDED Requirements

### Requirement: OSD de volumen reactivo
El sistema SHALL mostrar un OSD cuando cambie el volumen o el estado de mute del sink por defecto, reaccionando a cualquier fuente del cambio (teclas de volumen, mezclador, dashboard, IPC), porque observa PipeWire y no eventos de teclado.

#### Scenario: Cambio desde el mezclador
- **WHEN** el usuario cambia el volumen desde pavucontrol
- **THEN** el OSD aparece con el nuevo valor

#### Scenario: Sin cambio de estado
- **WHEN** el volumen no cambia
- **THEN** el OSD no aparece

### Requirement: Auto-ocultado
El sistema SHALL ocultar el OSD automáticamente unos 2 segundos después del último cambio, manteniéndolo visible si los cambios son consecutivos.

#### Scenario: Cambios consecutivos
- **WHEN** el usuario sube el volumen tres veces seguidas con menos de 2 s entre cada una
- **THEN** el OSD permanece visible y se oculta recién 2 s después del último cambio

### Requirement: Representación del nivel
El sistema SHALL mostrar en el OSD el porcentaje de volumen, un ícono acorde al nivel (mute, bajo, medio, alto) y una barra proporcional, con los colores del tema.

#### Scenario: Volumen silenciado
- **WHEN** el sink queda muteado al 50 %
- **THEN** el OSD muestra el ícono de mute junto al valor 50 %

# notifications

## Purpose

Servidor de notificaciones de Selene sobre org.freedesktop.Notifications: popups con urgencia, acciones, historial y badge en la barra, reemplazando a dunst cuando Selene posee el bus.

## Requirements

### Requirement: Servir org.freedesktop.Notifications
El sistema SHALL registrar un servidor de notificaciones en el bus de sesión cuando ningún otro daemon (p. ej. dunst) lo posea, mostrando las notificaciones entrantes como popups en la esquina superior derecha bajo la barra.

#### Scenario: Notificación simple
- **WHEN** una aplicación envía una notificación normal y Selene posee el bus
- **THEN** aparece un popup con ícono, título y cuerpo, que expira según su timeout

#### Scenario: Bus ocupado por otro daemon
- **WHEN** dunst u otro daemon ya posee org.freedesktop.Notifications
- **THEN** Selene no registra su servidor, lo registra en su log, y el resto de la shell funciona con normalidad

### Requirement: Tratamiento por urgencia
El sistema SHALL tratar las notificaciones según su urgencia: las críticas no se auto-expiran y se distinguen con el color urgente del tema; las de baja urgencia tienen apariencia atenuada.

#### Scenario: Notificación crítica
- **WHEN** llega una notificación con urgency=critical
- **THEN** el popup permanece hasta que el usuario lo cierre y usa el color urgente del tema

### Requirement: Acciones de notificación
El sistema SHALL renderizar las acciones de una notificación como botones clickeables que invocan la acción correspondiente, y cerrar la notificación al activar una.

#### Scenario: Acción invocada
- **WHEN** el usuario hace clic en la acción "Responder" de un popup
- **THEN** se invoca dicha acción en la aplicación emisora y el popup se cierra

### Requirement: Historial y badge
El sistema SHALL mantener un historial de las últimas notificaciones (aunque los popups hayan expirado), mostrar un badge con la cantidad no leídas en la barra y permitir abrir el historial y limpiarlo desde ahí.

#### Scenario: Popup expirado queda en historial
- **WHEN** un popup expira sin interacción del usuario
- **THEN** la notificación queda en el historial y el badge incrementa

### Requirement: Modo no-molestar
El sistema SHALL soportar un modo no-molestar que suprime los popups pero sigue registrando notificaciones en el historial, activable desde el dashboard o IPC.

#### Scenario: DND activo
- **WHEN** el modo no-molestar está activo y llega una notificación normal
- **THEN** no aparece popup pero la notificación queda en el historial

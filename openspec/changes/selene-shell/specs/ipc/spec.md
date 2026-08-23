# ipc

## Purpose

Superficie de control externa de Selene: comandos invocables con `qs -c selene ipc <comando>` desde la terminal o binds de Hyprland, para operar overlays, tema y notificaciones sin tocar el mouse.

## ADDED Requirements

### Requirement: Comandos de control de overlays
El sistema SHALL exponer comandos IPC que abren/cierran (toggle) los overlays en el monitor enfocado: `toggleLauncher`, `toggleDashboard`, `togglePower`.

#### Scenario: Toggle de launcher desde un bind
- **WHEN** un bind de Hyprland ejecuta `qs -c selene ipc toggleLauncher`
- **THEN** el launcher se abre si estaba cerrado o se cierra si estaba abierto

### Requirement: Comandos de tema
El sistema SHALL exponer el comando IPC `theme-reload` que re-deriva la paleta desde el bundle activo de moonarch y la aplica inmediatamente.

#### Scenario: Re-tema manual
- **WHEN** se ejecuta `qs -c selene ipc theme-reload` tras cambiar el tema de moonarch
- **THEN** la shell completa se recolorea de inmediato

### Requirement: Comandos de notificaciones
El sistema SHALL exponer comandos IPC para activar/desactivar el modo no-molestar (`dnd`) y limpiar el historial de notificaciones (`clear-notifs`).

#### Scenario: Activar DND por IPC
- **WHEN** se ejecuta `qs -c selene ipc dnd`
- **THEN** el modo no-molestar cambia de estado y el dashboard lo refleja

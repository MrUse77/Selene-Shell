# session-power

## Purpose

Menú de sesión de Selene: overlay con las acciones de apagado, reinicio, suspensión, bloqueo y cierre de sesión, usando los mecanismos estándar del sistema.

## Requirements

### Requirement: Acciones de sesión
El sistema SHALL proveer un overlay con las acciones: apagar (`systemctl poweroff`), reiniciar (`systemctl reboot`), suspender (`systemctl suspend`), bloquear (hyprlock) y cerrar la sesión de Hyprland, cada una identificada con ícono y color semántico del tema (peligro, advertencia, acento).

#### Scenario: Apagar
- **WHEN** el usuario elige "Apagar" en el overlay
- **THEN** se ejecuta el apagado del sistema

#### Scenario: Bloquear
- **WHEN** el usuario elige "Bloquear" en el overlay
- **THEN** hyprlock bloquea la sesión

### Requirement: Cierre del overlay
El sistema SHALL cerrar el overlay con Escape o clic fuera de su área, sin ejecutar ninguna acción.

#### Scenario: Cancelar
- **WHEN** el usuario pulsa Escape con el overlay abierto
- **THEN** el overlay se cierra y no se ejecuta ninguna acción de sesión

### Requirement: Acceso desde barra e IPC
El sistema SHALL permitir abrir el menú de sesión desde un botón de la barra y mediante comando IPC.

#### Scenario: Apertura por IPC
- **WHEN** se ejecuta `qs -c selene ipc togglePower`
- **THEN** el overlay de sesión se abre en el monitor enfocado

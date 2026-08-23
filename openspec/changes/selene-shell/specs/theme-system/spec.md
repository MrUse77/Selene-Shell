# theme-system

## Purpose

Define cómo Selene obtiene su paleta de colores y tokens de diseño desde los bundles de temas de moonarch, con fallback seguro y re-tema en vivo, para que toda la shell siga al tema seleccionado sin reiniciar.

## ADDED Requirements

### Requirement: Derivar paleta desde el bundle activo de moonarch
El sistema SHALL derivar la paleta de colores leyendo `~/.local/share/moonarch/themes/current/ghostty.conf` (colores ANSI 0–15, background, foreground) y completar acentos con `~/.local/share/moonarch/themes/current/waybar.css` cuando esté disponible. Los tokens derivados (fondo, superficies, texto, acento, urgentes, glow) MUST ser consumidos por todos los módulos, sin colores hardcodeados por módulo.

#### Scenario: Bundle válido presente
- **WHEN** el symlink `themes/current` apunta a un bundle con `ghostty.conf` parseable
- **THEN** la shell renderiza todos sus módulos con la paleta derivada de ese bundle

#### Scenario: Acento preferente de waybar.css
- **WHEN** `waybar.css` del bundle define `accent_blue` y `urgent_red`
- **THEN** esos valores tienen prioridad sobre los derivados de la paleta ANSI para acento y urgente

### Requirement: Fallback Tokyo Night
El sistema SHALL caer a una paleta Tokyo Night embebida cuando moonarch no esté disponible, el symlink `current` esté roto o los fragmentos no sean parseables, sin interrumpir el arranque de la shell.

#### Scenario: moonarch ausente
- **WHEN** no existe `~/.local/share/moonarch/themes/current/`
- **THEN** la shell arranca normalmente con la paleta Tokyo Night embebida

### Requirement: Re-tema en vivo al cambiar de tema
El sistema SHALL detectar el cambio de target del symlink `themes/current` (mecanismo atómico del theme-selector) en un plazo máximo de unos segundos y re-derivar la paleta, repintando todos los módulos sin reiniciar el proceso.

#### Scenario: Cambio de tema con el selector
- **WHEN** el usuario cambia de tema con moonarch (SUPER+SHIFT+T) mientras Selene corre
- **THEN** barra, overlays y notificaciones se recolorean con la paleta del nuevo bundle sin reiniciar

### Requirement: Refresh manual por IPC
El sistema SHALL proveer un comando IPC `theme-reload` que re-deriva y aplica la paleta inmediatamente, sin esperar la detección periódica.

#### Scenario: Refresh inmediato
- **WHEN** se ejecuta `qs -c selene ipc theme-reload`
- **THEN** la paleta se re-deriva desde el bundle actual y se aplica al instante

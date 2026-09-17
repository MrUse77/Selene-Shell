# Proposal: selene-shell

## Why

El stack de shell actual de MoonArch está fragmentado (waybar + eww + dunst + rofi, cada uno con su lenguaje visual y su formato de config) y solo waybar/hyprland/ghostty/rofi reaccionan al selector de temas de moonarch: eww y dunst quedan hardcodeados a tokyo-night al cambiar de tema. Una shell única basada en Quickshell/QML permite unificar barra, launcher, dashboard, notificaciones, OSD y menú de sesión con una identidad visual propia, animaciones coherentes con Hyprland y —por primera vez— theming en vivo 100% moonarch-aware.

## What Changes

- Se agrega **Selene**, la shell de MoonArch: una config de Quickshell en QML que vive en la raíz de este proyecto (`shell.qml` + `Services/` + `Components/` + `Modules/`) y se ejecuta como `qs -c selene`.
- **Identidad propia** (no es un calco de caelestia ni de waybar): lenguaje "lunar" — cápsulas (radius = altura/2), glow tenue de acento en el elemento activo, fase lunar real en el reloj, indicador de workspace que se desliza; movimiento fluido usando los beziers reales de `hyprland.lua` (`smooth`, `easeOutQuint`, `overshot`, `gentle`) con duraciones ≈ `1000/speed`.
- **Primer componente 100% moonarch-aware**: la paleta se deriva en runtime desde `~/.local/share/moonarch/themes/current/ghostty.conf` (16 colores ANSI, obligatorio en todos los bundles) + `waybar.css` (acentos), con fallback Tokyo Night; al cambiar de tema con SUPER+SHIFT+T la shell completa se recolorea sin reiniciar.
- Módulos: barra por monitor (workspaces SMW-aware, título de ventana, tray, media, volumen, CPU/RAM, updates, reloj + calendario), launcher (drun fuzzy + cálculo con "="), dashboard bento (usuario, toggles, volumen, gauges, MPRIS, power), notificaciones (reemplaza dunst al probar), OSD de volumen, menú de sesión.
- IPC: comandos `qs -c selene ipc ...` (toggles de overlays, `theme-reload`) listos para cablear binds en `hyprland.lua`.
- NO cambia: moonarch, `hyprland.lua`, autostart, ni configs de waybar/eww/dunst/rofi. La integración oficial con moonarch (fragmento por bundle, `required_files`, señal de reload) se documenta como hoja de ruta en el README de este change, sin ejecutarse acá.

## Capabilities

### New Capabilities

- `theme-system`: derivación de tokens de diseño desde los bundles de moonarch (fallback Tokyo Night), re-tema en vivo al swap del symlink `current` y refresh manual por IPC.
- `bar`: barra de cápsulas por monitor con workspaces (5 por monitor, split-monitor-workspaces), título de ventana enfocada, tray, media, volumen, CPU/RAM, updates y reloj con fase lunar + calendario popup.
- `launcher`: launcher de aplicaciones con búsqueda fuzzy sobre DesktopEntries, navegación por teclado y cálculo aritmético inline con prefijo `=`.
- `dashboard`: panel de control estilo bento con usuario/uptime/fase lunar, toggles rápidos, volumen, gauges de CPU/RAM/disco y reproductor MPRIS completo.
- `notifications`: servidor de notificaciones (org.freedesktop.Notifications) con popups por urgencia, acciones, historial y badge en la barra.
- `osd`: OSD de volumen reactivo a cambios de PipeWire (independiente de la tecla que lo dispare) con auto-ocultado.
- `session-power`: overlay de sesión con apagar, reiniciar, bloquear, cerrar sesión y suspender.
- `ipc`: superficie de control externa vía `qs -c selene ipc ...`.

### Modified Capabilities

(ninguna — raíz OpenSpec nueva, sin specs previos)

## Impact

- **Código nuevo** en la raíz del proyecto: ~30 archivos QML + README. Sin tocar otros árboles.
- **Dependencia nueva**: `quickshell-git` (AUR) y symlink `~/.config/quickshell/selene -> ~/Dev/Lab/QML`.
- **Runtime**: convive con waybar/dunst (se detienen solo para pruebas y se restauran); mientras dunst posea el bus de notificaciones, el módulo de notificaciones no puede registrar el servidor (el resto funciona).
- **Futuro** (fuera de este change): incorporación a moonarch vía fragmento `quickshell.json` por bundle + alta en `required_files` + señal en `reload_consumers()`; ojo con `tests/moonarch-theme-palette_test.sh` que pinea por hash los archivos del bundle tokyo-night.

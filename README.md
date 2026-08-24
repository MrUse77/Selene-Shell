# Selene — la shell de MoonArch

Shell de escritorio para Quickshell/QML sobre Hyprland. Selene usa la paleta
MoonArch activa y una identidad visual propia basada en cápsulas, tarjetas,
glow tenue, fase lunar y las curvas de animación del compositor.

## Inicio e IPC

Hyprland inicia una única instancia con:

```sh
qs -c selene
```

Entradas IPC públicas:

```sh
qs -c selene ipc call selene openApps       # aplicaciones + selector de modo
qs -c selene ipc call selene openWindows    # ventanas activas
qs -c selene ipc call selene openRun        # ejecutar comando sin shell implícito
qs -c selene ipc call selene openThemes     # temas MoonArch validados
qs -c selene ipc call selene togglePower    # menú de sesión
qs -c selene ipc call selene toggleDashboard
qs -c selene ipc call selene themeReload
qs -c selene ipc call selene dnd
qs -c selene ipc call selene clearNotifs
```

`toggleLauncher` se conserva como alias IPC compatible, pero las integraciones
nuevas deben abrir el modo concreto.

## Atajos migrados desde Rofi

| Atajo | Selene |
| --- | --- |
| `SUPER+M` | Apps; `Tab`/`Shift+Tab`, `Ctrl+1…4` o las cápsulas cambian entre Apps, Active Apps, Run y Themes |
| `SUPER+Tab` | buscador de ventanas Hyprland activas; enfoca la elegida |
| `SUPER+R` | runner con argumentos separados por comillas/escapes y errores visibles |
| `SUPER+SHIFT+X` | Lock/Sleep inmediatos; Log out/Reboot/Shutdown piden confirmación |
| `SUPER+SHIFT+T` | selector buscable de IDs que `moonarch/theme-selector --list` valida dinámicamente |

El prefijo `=` activa la calculadora desde el launcher unificado; `Enter` copia
el resultado mediante `wl-copy`. El click del lanzador y del botón de energía
de Waybar apunta a los mismos IPC aunque Waybar quede como fallback dormido.

## Theming MoonArch

`Services/Theme.qml` deriva tokens desde
`~/.local/share/moonarch/themes/current/waybar.css` y `ghostty.conf`, con
fallback integrado. El selector no duplica la lógica de cambio: Selene lista y
aplica mediante `~/.local/bin/moonarch/theme-selector --list|--apply ID`, que
mantiene validación, swap atómico, reload y rollback. Tras aplicar, Selene
recarga los tokens inmediatamente; el poll de archivos queda como respaldo.

## Rollback

Los cinco archivos de `~/.config/rofi` se conservan byte por byte. Para volver:

1. quitá `qs -c selene` del autostart de Hyprland y reactivá `waybar`/`dunst`;
2. restaurá los binds de Hyprland a `~/.config/rofi/scripts/launch`,
   `launch-powermenu` y al selector sin argumentos;
3. restaurá los clicks del Waybar dormido a esos mismos scripts.

El selector sin argumentos sigue abriendo su UI Rofi, así que ese camino no
depende de Selene. Eww permanece configurado y `SUPER+N` no cambia.

## Estructura

```text
shell.qml               composición por pantalla + IPC
Services/               Theme, Anim, estado y coordinación global de overlays
Components/             Card, Capsule, MoonDisc y controles compartidos
Modules/Bar/             barra Selene
Modules/Launcher/        Apps, Active Apps, Run, Themes y calculadora
Modules/PowerMenu/       acciones de sesión y confirmaciones destructivas
Modules/Dashboard/       control center
Modules/Notifications/   servidor e historial freedesktop
Modules/Osd/             OSD de volumen
```

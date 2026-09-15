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
el resultado mediante `wl-copy`. Selene es el único dueño del escritorio: barra,
lanzador, notificaciones, OSD, menú de sesión y dashboard salen de este proceso,
y el stack que cumplía esos roles antes —Waybar, Rofi, Eww y Dunst— ya no está
en el repositorio de dotfiles.

## Theming MoonArch

`Services/Theme.qml` deriva tokens desde
`~/.local/share/moonarch/themes/current/waybar.css` y `ghostty.conf`, con
fallback integrado. El selector no duplica la lógica de cambio: Selene lista y
aplica mediante `~/.local/bin/moonarch/theme-selector --list|--apply ID`, que
mantiene validación, swap atómico, reload y rollback. Tras aplicar, Selene
recarga los tokens inmediatamente; el poll de archivos queda como respaldo.

## Rollback

Waybar, Rofi, Eww y Dunst ya no están en el repositorio: su configuración se
eliminó y el instalador dejó de ofrecer sus paquetes. Volver atrás es una
operación de Git, no un cambio de binding:

1. `git revert` del squash que integró la migración en `MoonArch`, para recuperar
   las cuatro configuraciones y las entradas del instalador;
2. reinstalar los paquetes que necesites (`paru -S waybar rofi dunst`), porque el
   instalador ya no los incluye;
3. quitar `qs -c selene` del autostart de Hyprland y recargar la sesión.

El selector sin argumentos **delega en Selene** (`qs -c selene ipc call selene
openThemes`): no abre una UI propia, y si Quickshell no está corriendo falla con
un mensaje que nombra `--list` y `--apply`. Esos dos modos, más la forma
posicional, siguen funcionando sin Selene.

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

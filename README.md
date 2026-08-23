# Selene — la shell de MoonArch

Shell de escritorio para Quickshell/QML sobre Hyprland, con identidad lunar
propia: cápsulas, glow tenue de acento, fase lunar real y animaciones que
replican los beziers del compositor. Primer componente 100% **moonarch-aware**:
deriva su paleta de los bundles de temas en vivo.

## Correr

```sh
qs -c selene          # el symlink ~/.config/quickshell/selene apunta a este dir
```

Hot reload: al guardar cualquier archivo la shell se actualiza sola.

Conviene detener waybar/dunst mientras se prueba (la barra ocupa la misma
zona y dunst pelea el bus de notificaciones):

```sh
pkill waybar; pkill dunst; qs -c selene
```

## IPC

```sh
qs -c selene ipc call selene toggleLauncher    # abrir/cerrar launcher
qs -c selene ipc call selene toggleDashboard   # dashboard (como tu eww SUPER+N)
qs -c selene ipc call selene togglePower       # menú de sesión
qs -c selene ipc call selene themeReload       # re-derivar paleta moonarch YA
qs -c selene ipc call selene dnd               # alternar no-molestar
qs -c selene ipc call selene clearNotifs       # limpiar historial de notificaciones
```

Otros subcomandos útiles: `qs -c selene ipc show` (lista targets), `qs -c selene list --all` (instancias).

Listos para cablear binds en `hyprland.lua`, p. ej.:

```lua
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs -c selene ipc toggleDashboard"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("qs -c selene ipc toggleLauncher"))
```

## Estructura

```
shell.qml               entry point: barras por monitor + overlays + IPC
Services/               singletons: Theme (moonarch), Anim (beziers hyprland),
                        Moon (fase lunar), Hardware, Audio, Updates, State
Components/             Capsule, Card, Gauge, StyledSlider, MoonDisc
Modules/
  Bar/                  barra por monitor: workspaces SMW (indicador deslizante),
                        título de ventana, tray, media, volumen, cpu/ram, updates,
                        notifs, reloj+luna, calendario, historial, power
  Launcher/             drun fuzzy + "=" cálculo (copia con wl-copy)
  Dashboard/            drawer bento: usuario, toggles (bt/DND), volumen,
                        gauges, MPRIS completo, sesión
  Notifications/        servidor freedesktop con urgencias, acciones, historial
  Osd/                  OSD de volumen reactivo a PipeWire
  PowerMenu/            overlay de sesión
```

## Theming moonarch (cómo funciona hoy)

`Services/Theme.qml` lee en vivo `~/.local/share/moonarch/themes/current/`:

1. `waybar.css` — `@define-color` (bg_dark, text_main, accent_blue, urgent_red)
2. `ghostty.conf` — paleta ANSI 0–15 + background/foreground/selection
3. Fallback Tokyo Night embebido si no hay moonarch

Como el selector swapea el symlink `current` sin cambiar la ruta, el tema se
re-deriva por poll (2 s) o al instante con `ipc themeReload`. Cambiá de tema
con SUPER+SHIFT+T y Selene se recolorea entera — cosa que eww/dunst no hacen.

## Hoja de ruta: incorporación oficial a moonarch

1. Agregar un fragmento `quickshell.json` (o `.qml`) por bundle en
   `home/.local/share/moonarch/themes/<tema>/` del repo MoonArch.
2. `Theme.qml` ya está preparado: si aparece `current/quickshell.json` tiene
   prioridad sobre la derivación (hook documentado en el código).
3. Sumar el archivo a `required_files` en `~/.local/bin/moonarch/theme-selector`
   (ojo: exige que los 12 bundles lo traigan).
4. Agregar la señal de reload en `reload_consumers()` y `refresh_best_effort()`:
   `pgrep -x qs && qs -c selene ipc themeReload` (o SIGUSR2 si se implementa).
5. ⚠️ `tests/moonarch-theme-palette_test.sh` pinea por hash los archivos del
   bundle tokyo-night: tocar ese bundle exige actualizar los hashes del test.

## Estado

- Shell QML implementada; no hay una verificación sintáctica integral reproducible documentada.
- **Pendiente de verificación en runtime** (primer arranque): ver
  `openspec/changes/selene-shell/tasks.md` — las tareas de verificación visual
  (fase 4/6 con grim) siguen abiertas.

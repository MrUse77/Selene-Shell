# Design: selene-shell

## Context

Ver `proposal.md` (Why) para la motivación. Estado actual relevante: Hyprland 0.56.2 con config nativa en Lua, 2 monitores 1080p, theme manager moonarch con bundles en `~/.local/share/moonarch/themes/<id>/` (fragmentos por app, symlink `current` con swap atómico), animaciones definidas con 4 beziers propios, stack waybar + eww + dunst + rofi, Quickshell no instalado (`paru` disponible). Fuentes de datos del sistema: PipeWire/WirePlumber, NetworkManager, Bluetooth activos; sin batería ni backlight (desktop con monitores externos); MPRIS vía navegador/playerctld.

## Goals / Non-Goals

**Goals:**

- Una config Quickshell ejecutable como `qs -c selene`, completa (barra, launcher, dashboard, notificaciones, OSD, sesión, IPC) y con identidad visual propia.
- Theming derivado de moonarch en runtime, con re-tema en vivo y fallback seguro.
- Animaciones coherentes con Hyprland (mismas curvas, duraciones proporcionales).
- Código mantenible: servicios como singletons, UI desacoplada de la fuente de datos.

**Non-Goals:**

- No modificar moonarch, `hyprland.lua`, autostart ni configs de waybar/eww/dunst/rofi (la integración oficial queda documentada como hoja de ruta).
- No reemplazar permanentemente el stack actual; coexistencia durante desarrollo.
- Sin lockscreen propio (hyprlock ya existe y cumple), sin widgets de batería/backlight (hardware no aplica), sin wallpaper engine (hyprpaper ya cumple).

## Decisions

### D1: Runtime — `quickshell-git` (AUR)
La versión estable 0.3.1 carece de APIs que usamos (modelo de objetos de Pipewire, eventos de Hyprland, menús de SystemTray). La comunidad (caelestia, AX-Shell) targeting git. Alternativa considerada: estable — descartada por APIs faltantes. Riesgo asociado en Riesgos.

### D2: Arquitectura — `shell.qml` fino + `Services/` + `Components/` + `Modules/`
Entry point mínimo que monta módulos; `Services/` son singletons QML (`pragma Singleton`) que exponen estado (Theme, Anim, Moon, Hardware, Audio, Updates); `Components/` widgets reutilizables (Capsule, Gauge, StyledSlider); `Modules/` una carpeta por pieza de UI. Racional: la UI no conoce las fuentes de datos (fácil swap de backend), el patrón es el estándar de la comunidad Quickshell pero el diseño visual es propio. Alternativa: archivos sueltos — descartada por acoplamiento.

### D3: Tema — derivar de `ghostty.conf` + `waybar.css` con fallback embebido
`ghostty.conf` es el fragmento más rico (16 colores ANSI + bg/fg/selection/cursor) y es `required_file` del theme-selector, o sea que existe en los 12 bundles y en los futuros. `waybar.css` aporta acentos preferentes (`accent_blue`, `urgent_red`) cuando está. La derivación mapea: bg ← background, superficie ← mezcla bg/selection, texto ← foreground, cian ← ANSI 6, púrpura ← 5, verde ← 2, naranja ← 3, urgentes ← 1/waybar. Alternativa considerada: fragmento `quickshell.json` dedicado por bundle — mejor contrato a futuro pero exige tocar moonarch (12 bundles + `required_files` + tests que pinean hashes); se documenta como hoja de ruta y el servicio Theme ya deja el hook para leerlo cuando exista.

### D4: Detección de cambio de tema — poll liviano + IPC
El selector swapea el symlink `current` atómicamente (`mv -Tf`); un watcher de inodo sobre el archivo apuntado no se dispara al re-apuntar el symlink. Solución: poll cada ~2 s comparando `realpath` + mtime (barato), más `theme-reload` IPC para refresh instantáneo. Alternativa: watcher sobre el directorio de temas — Quickshell no expone watch de directorios.

### D5: Animación — singleton `Anim` con los beziers de Hyprland
`hyprland.lua` define `smooth (0.5,0)(0.5,1)`, `easeOutQuint (0.23,1)(0.32,1)`, `overshot (0.13,0.99)(0.29,1.05)`, `gentle (0.25,0.1)(0.25,1)`. Se replican como `easing.bezierCurve` con duraciones ≈ `1000/speed` ms (layers ≈170–250 ms, launcher popin ≈200 ms, workspaces ≈220 ms). Racional: la shell y el compositor deben sentirse como un solo sistema.

### D6: Identidad visual — cápsulas, glow lunar, fase lunar real, Nerd Font
Cápsulas (radius = altura/2) en la barra — distinto de los rects de 14 px de waybar; tarjetas bento de radio grande en el dashboard; glow = borde 1 px de acento + halo de baja alfa solo en el elemento activo; indicador de workspace que se desliza (no teleport); fase lunar calculada astronómicamente (algoritmo de ciclo de Conway simplificado) como firma en reloj y dashboard. Íconos: glifos Nerd Font únicamente (no hay Material Symbols instalados; no agregar dependencia de fuentes).

### D7: Ventanas — layer-shell según rol
Barra: `PanelWindow` anclada arriba con zona exclusiva por monitor (`Variants` sobre pantallas). Overlays (launcher, dashboard, power): `PanelWindow` en layer `overlay`, centrados en el monitor enfocado, con foco de teclado exclusivo al abrirse. Popups (calendario, historial, OSD): sin zona exclusiva, se superponen.

### D8: Datos del sistema — servicios propios sobre APIs Quickshell y /proc
Volumen: servicio Quickshell Pipewire (sink por defecto). MPRIS: servicio Quickshell Mpris. Tray: SystemTray con menús. Notificaciones: NotificationServer. CPU/RAM: lectura de `/proc/stat` y `/proc/meminfo` con reload periódico (los archivos /proc reportan tamaño 0, los watchers de FileView no sirven ahí → Timer). Disco: `df --output=pcent`. Updates: `checkupdates` + `paru -Qua` con caché larga y refresh manual (son llamadas lentas de red).

### D9: Desarrollo y verificación — symlink + hot reload + screenshots
`~/.config/quickshell/selene -> ~/Dev/Lab/QML`, correr `qs -c selene`, iterar con hot reload. Verificación visual con `grim -o <monitor>` y lectura de las capturas, en ambos monitores. Waybar/dunst se detienen solo durante las pruebas y se relanzan al terminar.

## Risks / Trade-offs

- [quickshell-git cambia APIs entre versiones] → Los servicios propios (D2/D8) contienen el uso de APIs externas en pocos archivos; al actualizar, el impacto queda localizado en `Services/`.
- [Polling de /proc cada 2 s consume CPU] → Timers pausados cuando el consumidor no es visible (p. ej. dashboard cerrado); intervalo conservador.
- [Bus de notificaciones ocupado por dunst] → Degradación especificada (spec `notifications`): sin registro, warn en log, resto funcional.
- [Swap de symlink no dispara watchers] → Poll + IPC (D4); costo mínimo.
- [Derivación de paleta imperfecta para algún tema] → Fallback Tokyo Night garantiza arranque; el hook de fragmento dedicado permite afinar por tema más adelante.
- [Gusto visual subjetivo] → Verificación con screenshots e iteración rápida por hot reload antes de dar por cerrado el change.

## Migration Plan

Despliegue: instalar `quickshell-git`, crear symlink `~/.config/quickshell/selene`, ejecutar `qs -c selene` manualmente (nada del autostart cambia). Rollback: `pkill qs`, borrar el symlink y (opcional) `paru -R quickshell-git`; el resto del stack nunca se tocó. Integración futura en moonarch (change aparte): fragmento por bundle, alta en `required_files`, señal en `reload_consumers()`, y atención a `tests/moonarch-theme-palette_test.sh` (hashes pineados del bundle tokyo-night).

## Open Questions

- Formato final del fragmento moonarch para Quickshell (`quickshell.json` vs `.qml` con bindings) y si entra en `required_files` — se decide en el change de moonarch; el hook de Theme ya lo contempla.
- Brillo de monitores externos vía DDC (`ddcutil` + permisos i2c) como toggle/slider futuro del dashboard — extensión opcional, no bloquea nada.

## Notas de verificación de API (tarea 1.3, contra docs v0.3.x del build instalado)

Confirmaciones y desvíos respecto de los supuestos iniciales:

- `FileView`: el texto NO es propiedad, es la función `text()`; `watchChanges` inútil para `/proc` (tal como se diseñó: Timer + `reload()`).
- `NotificationServer` NO tiene propiedad `dnd`: el DND es estado propio de Selene que suprime popups y guarda historial (como especifica la spec).
- `Notification.actions` es `list<NotificationAction>` plano (no ObjectModel); `expireTimeout` en segundos; cerrar con `expire()`/`dismiss()` (no hay `close(reason)`).
- `MprisPlayer`: la propiedad es `isPlaying` (no `playing`), `position`/`length` en segundos, y `position` NO es reactivo — hay que emitir `positionChanged()` desde un Timer (ticker del dashboard).
- Hyprland: no existe `HyprlandClient`; para títulos se usa `Hyprland.activeToplevel` / `toplevels` (con `monitor` por toplevel) y `monitorFor(screen)` para filtrar por barra.
- `DesktopEntries.applications` ya viene filtrado (sin Hidden/NoDisplay); lanzar con `entry.execute()`.
- `SystemTrayItem.menu` es un handle que se abre con `QsMenuAnchor { menu: item.menu; anchor: <item> }` + `open()`.
- `PanelWindow.focusable` mapea a keyboardFocus de layer-shell: suficiente para overlays (launcher/power).
- `PwNodeAudio` exige `PwObjectTracker { objects: [sink] }` para que volumen/mute sean válidos.
- Tooling: `qmlformat` no parsea optional chaining (`?.`) — válido igualmente para el engine Qt 6; la validación de sintaxis se hizo con transformación temporal.

## Notas de verificación en runtime (primer arranque)

- Bugs encontrados y corregidos: imports relativos case-sensitive (`Services` capitalizado); `IpcHandler` vive en `Quickshell.Io`; con `qmldir` presente los tipos locales solo se resuelven vía qmldir (completar el de `Modules/Bar`); `QsMenuAnchor.anchor` es grupo read-only → usar `anchor.item`; singleton `State` colisionaba con `QtQuick.State` → renombrado `ShellState`; `width/height` deprecados en ventanas layer → `implicit*`; **declarar `modelData` a nivel instancia en `Variants` sombreaba la asignación** — la propiedad debe declararse en el propio componente.
- El modelo `Hyprland.workspaces` se puebla de forma asincrónica (~4 s tras el arranque); las barras deben tolerar el vacío inicial (fallback numérico).
- Re-tema moonarch en vivo verificado con round-trip tokyo-night ⇄ catppuccin-mocha (poll de FileView + comparación de texto). Latencia observada con poll de 2 s: hasta ~12 s (reload asincrónico; el primer ciclo tras el swap puede re-leer contenido viejo) → intervalo bajado a 1 s.
- Notificaciones: mientras dunst posea el bus, el servidor no registra (warn en log, todo lo demás funcional) — degradación conforme a spec.

# Tasks: selene-shell

> Las tareas que combinan implementación con comprobaciones visuales o de runtime
> quedan abiertas hasta registrar evidencia reproducible de esas comprobaciones.

## 1. Setup

- [x] 1.1 Instalar `quickshell-git` con paru y verificar con `qs --version` que el binario `qs` queda disponible
- [x] 1.2 Crear symlink `~/.config/quickshell/selene -> ~/Dev/Lab/QML` y verificar con `readlink`
- [x] 1.3 Verificar contra las docs de la versión instalada las APIs exactas a usar (Pipewire, Mpris, SystemTray, NotificationServer, DesktopEntries, FileView, Hyprland) y anotar desvíos respecto de este design en `design.md`
- [x] 1.4 Leer formatos reales de `themes/current/ghostty.conf` y `waybar.css` de los 12 bundles y documentar el mapa de derivación de tokens en el código de Theme

## 2. Services

- [ ] 2.1 Crear `Services/Anim.qml` (beziers smooth/easeOutQuint/overshot/gentle como `easing.bezierCurve` + duraciones) y verificar con un Rectángulo de prueba que las curvas animan
- [ ] 2.2 Crear `Services/Theme.qml` (parseo moonarch + fallback Tokyo Night + poll de realpath/mtime + hook para fragmento futuro) y verificar en consola que deriva la paleta de tokyo-night y cae al fallback si se apunta `current` a un bundle inexistente
- [ ] 2.3 Crear `Services/Moon.qml` (fase lunar + nombre de fase) y verificar contra una referencia conocida que la fase del día es correcta
- [ ] 2.4 Crear `Services/Hardware.qml` (CPU desde /proc/stat, RAM desde /proc/meminfo, disco vía df, temperatura; poll 2 s pausable) y verificar que los valores coinciden con `btop`/`free` en el mismo instante
- [ ] 2.5 Crear `Services/Audio.qml` (volumen y mute del sink por defecto vía Pipewire) y verificar que refleja cambios hechos con `wpctl setvolume`
- [ ] 2.6 Crear `Services/Updates.qml` (checkupdates + paru -Qua con caché y refresh manual) y verificar que el conteo coincide con la salida de los comandos

## 3. Components

- [ ] 3.1 Crear `Components/Capsule.qml` (cápsula translúcida, borde acento, glow opcional, estados hover/press animados con Anim) y verificar visualmente hover/press en una ventana de prueba
- [ ] 3.2 Crear `Components/Gauge.qml` (gauge circular fino con umbral de color) y verificar que dibuja 0 %, 50 % y 100 % correctamente
- [ ] 3.3 Crear `Components/StyledSlider.qml` (slider pill con relleno de color y reacción en vivo) y verificar arrastre y reflejo de cambios externos

## 4. Módulos — Barra

- [ ] 4.1 Crear `Modules/Bar/Bar.qml` (PanelWindow por monitor con Variants, layout de cápsulas, zona exclusiva) y verificar con grim que aparece una barra por monitor sin tapar ventanas
- [ ] 4.2 Implementar `Workspaces.qml` (5 por monitor, clic = dispatch, indicador deslizante, distinción de monitor enfocado) y verificar cambiando workspaces que el indicador se desliza al activo correcto
- [ ] 4.3 Implementar `WindowTitle.qml` (título de la ventana enfocada con elipsis) y verificar que cambia al mover el foco entre ventanas
- [ ] 4.4 Implementar `ClockWidget.qml` (hora + fase lunar + calendario popup navegable) y verificar que el calendario resalta hoy y navega meses
- [ ] 4.5 Implementar `AudioWidget.qml`, `HardwareWidget.qml` y `UpdatesWidget.qml` (con umbrales de color y ocultamiento del contador en 0) y verificar estados normales y de alerta
- [ ] 4.6 Implementar `Tray.qml` (íconos + menús) y verificar que los íconos del tray aparecen y sus menús abren
- [ ] 4.7 Implementar `MediaWidget.qml` (chip con título cuando hay reproducción, oculto si no) y verificar con reproducción en el navegador

## 5. Módulos — Overlays

- [ ] 5.1 Crear `Modules/Osd/Osd.qml` (volumen reactivo a PipeWire, %, ícono por nivel, barra, auto-hide 2 s con ventana deslizante) y verificando cambiando volumen desde `wpctl` y desde el dashboard que aparece y se oculta solo
- [ ] 5.2 Crear `Modules/Launcher/Launcher.qml` (drun fuzzy, teclado, `=` cálculo con copiado al portapapeles, popin overshot en monitor enfocado) y verificar lanzar Ghostty, navegar con flechas, calcular `=(2+3)*4` → 20 en el portapapeles con `wl-paste`
- [ ] 5.3 Crear `Modules/Dashboard/Dashboard.qml` (bento: usuario/uptime/fase lunar, toggles bluetooth+DND, volumen, gauges, MPRIS con selector de player, accesos power) y verificar slider refleja cambios externos, gauges vivos, controles MPRIS operan
- [ ] 5.4 Crear `Modules/Notifications/` (NotificationServer con degradación si dunst posee el bus, popups por urgencia, acciones, historial, badge) y verificar con `notify-send` en sus tres urgencias, con acciones, y el modo DND suprime popups
- [ ] 5.5 Crear `Modules/PowerMenu/PowerMenu.qml` (overlay apagar/reboot/suspender/lock/logout, Escape y clic-fuera cancelan) y verificando con comandos inofensivos sustituidos que las acciones correctas se invocan y Escape no ejecuta nada

## 6. Integración y pulido

- [ ] 6.1 Escribir `shell.qml` final (ShellRoot montando todo + foco de teclado de overlays) e `IpcHandler` (toggleLauncher, toggleDashboard, togglePower, theme-reload, dnd, clear-notifs) y verificar cada comando con `qs -c selene ipc ...`
- [ ] 6.2 Pasada de pulido: hover states en todos los interactivos, `Behavior` en propiedades animables, consistencia de spacing/tipografía/glifos; verificar con grim que no hay elementos estáticos bruscos
- [ ] 6.3 Prueba integral: detener waybar/dunst, correr `qs -c selene`, capturar ambos monitores con grim, iterar; cambiar de tema con el selector de moonarch en vivo y verificar re-tema completo; restaurar waybar/dunst al terminar

## 7. Documentación

- [x] 7.1 Escribir `README.md` (correr la shell, IPC disponible, hot reload) con la hoja de ruta de integración en moonarch (fragmento por bundle, `required_files`, señal en `reload_consumers()`, advertencia de tests con hashes pineados)
- [x] 7.2 Validación final: `openspec validate selene-shell` sin errores y las 8 specs consistentes con lo implementado

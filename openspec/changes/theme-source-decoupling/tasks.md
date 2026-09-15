# Tasks: theme-source-decoupling

## 1. Configuración

- [ ] 1.1 Verificar contra la versión de Quickshell instalada (`qs -V`) la API exacta de `ShellSettings`: cómo se declaran valores con default, dónde vive el archivo (`~/.config/quickshell/selene/shell.json` y variantes), y si `settings.watchFiles` ya alcanza para recargarlos en vivo. Anotar desvíos respecto de D2 en `design.md`.
- [ ] 1.2 Declarar dos settings con default de moonarch: `themesRoot` y `themeCommand`.
- [ ] 1.3 Implementar la cadena de resolución de D3 en `Services/Theme.qml` (`themesRoot`) y en `Modules/Launcher/Launcher.qml` (`themeCommand`), con el nombre neutro primero y `MOONARCH_*` como alias de compatibilidad.
  - Verificar: con la config actual, `readlink -f` del root resuelto da exactamente `~/.local/share/moonarch/themes`, y el comando resuelto sigue siendo `~/.local/bin/moonarch/theme-selector`.
  - Verificar: exportando `SHELL_THEMES_ROOT=/tmp/x` y arrancando, la shell intenta leer `/tmp/x/current/`; exportando `MOONARCH_THEMES_ROOT=/tmp/y` sin el neutro, hace lo mismo (compatibilidad).
- [ ] 1.4 Documentar las dos claves en el comentario de cabecera de `Theme.qml`, reemplazando la mención a `moonarch` como si fuera fija.

## 2. El comando de temas

- [ ] 2.1 Reemplazar el literal hardcodeado de `Launcher.qml` por el valor resuelto.
  - Verificar: `grep -n "theme-selector" Modules/Launcher/Launcher.qml` no devuelve ningún literal con `$HOME` concatenado.
- [ ] 2.2 Implementar la degradación de D4: si el comando está vacío o no existe (`Quickshell.env`/`FileView`/chequeo de existencia), el modo Themes lista los directorios de `themesRoot` en modo lectura y muestra un mensaje que explica que aplicar requiere un proveedor.
  - Verificar: apuntando `themeCommand` a un path inexistente, el modo Themes abre, lista los 12 bundles y muestra el mensaje; no se queda en `themesLoading` ni falla en silencio.
- [ ] 2.3 Verificar que el modo Themes sigue aplicando correctamente con el proveedor real: `qs -c selene ipc call selene openThemes`, elegir un bundle, y ver el cambio aplicado.

## 3. El override y su recarga

- [ ] 3.1 Agregar `overrideView.reload()` a `reloadTheme()` (D6).
  - Verificar: con un `quickshell.json` presente en el bundle activo, un `qs -c selene ipc call selene themeReload` tras cambiar de tema aplica la paleta del bundle **nuevo**, sin ventana de paleta mezclada.
- [ ] 3.2 Revisar el orden de aplicación para que el ciclo converja en una sola aplicación por cambio: hoy cada `onLoaded` de los tres `FileView` llama a `applyTheme`, así que un cambio dispara hasta tres aplicaciones. Evaluar si conviene agrupar o debouncear, y anotar la decisión en `design.md`.
- [ ] 3.3 Confirmar el comportamiento con el fragmento ausente (el caso de hoy): la derivación sigue igual y `_lastOverride` queda en `null` sin loguear ruido.

## 4. Contratos de test

- [ ] 4.1 Agregar a `tests/test_selene_corrections.py` un contrato que assertea que **el comando de temas no es un literal hardcodeado** en `Launcher.qml`, y que la resolución pasa por una fuente configurable.
- [ ] 4.2 Agregar un contrato para la degradación: que el modo Themes contempla el caso "sin comando" sin quedar en `themesLoading` (mismo estilo que `test_theme_loading_clears_stale_results_and_blocks_acceptance`).
- [ ] 4.3 Agregar un contrato para el override: que `reloadTheme()` recarga los **tres** `FileView`, no dos. Es la regresión de D6 y es exactamente lo que un test estructural puede fijar.
  - Verificar: revertir mentalmente el fix de 3.1 hace fallar este test.
- [ ] 4.4 Correr la suite completa: `python3 -m pytest tests/ -q` (o `python3 -m unittest discover -s tests`) sin regresiones.

## 5. Verificación end-to-end

- [ ] 5.1 Con `themeCommand` ausente, `themesRoot` válido: Themes lista en modo lectura, el resto de la shell arranca normalmente, y la paleta sale de la derivación de siempre.
- [ ] 5.2 Con todo en default (moonarch presente): comportamiento idéntico al de hoy, colores incluidos. Comparar contra una captura previa del `bg`/`accent` derivados.
- [ ] 5.3 Con `quickshell.json` presente en un bundle (crear uno de prueba **fuera** del repo de moonarch, por ejemplo en un root temporal): los tokens del JSON ganan, y ausente el JSON la shell sigue igual.
- [ ] 5.4 Arranque con el root apuntando a un directorio inexistente: la shell arranca con el fallback embebido y no se cuelga (esto ya lo cubre el requirement de fallback; se verifica que este cambio no lo rompió).

## 6. Cierre

- [ ] 6.1 Archivar este change y sincronizar el delta en `openspec/specs/theme-system/spec.md`.
- [ ] 6.2 Actualizar `ROADMAP.md`: marcar el contrato como hecho y dejar anotado qué queda del lado de moonarch (empaquetar `quickshell.json` en los 13 bundles, y la rama de reload de Waybar en `theme-selector`).
- [ ] 6.3 Bump del pin del submódulo en `MoonArch` cuando esto se publique, con su PR.

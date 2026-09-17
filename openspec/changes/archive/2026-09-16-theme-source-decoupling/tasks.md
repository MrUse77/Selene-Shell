# Tasks: theme-source-decoupling

## 1. Configuración

- [x] 1.1 Verificar contra la versión de Quickshell instalada (`qs -V`) la API exacta de `ShellSettings`: cómo se declaran valores con default, dónde vive el archivo (`~/.config/quickshell/selene/shell.json` y variantes), y si `settings.watchFiles` ya alcanza para recargarlos en vivo. Anotar desvíos respecto de D2 en `design.md`.
  - Verificado: `qs -V` → Quickshell 0.3.1; el `QuickshellSettings` instalado solo expone `workingDirectory` y `watchFiles`, sin soporte de settings custom ni `shell.json`. Desvío anotado en `design.md`.
- [x] 1.2 Declarar dos settings con default de moonarch: `themesRoot` y `themeCommand`.
  - Declarados en `shell.json` (valores `null` = usar el default del código) y resueltos por `Theme.qml` / `Launcher.qml`.
- [x] 1.3 Implementar la cadena de resolución de D3 en `Services/Theme.qml` (`themesRoot`) y en `Modules/Launcher/Launcher.qml` (`themeCommand`), con el nombre neutro primero y `MOONARCH_*` como alias de compatibilidad.
  - Verificado en runtime con una sonda aislada de Quickshell (`qs -p` sobre un `ShellRoot` mínimo que importa el `Theme.qml` real por symlink, sin barra, notificaciones, Hyprland ni D-Bus, sin tocar la sesión activa): sin configuración la raíz resuelta es exactamente `~/.local/share/moonarch/themes`; con `SHELL_THEMES_ROOT=/tmp/tsd-themes-a` la shell lee ese root y deriva su paleta; con `MOONARCH_THEMES_ROOT` sin la neutra hace lo mismo. La misma sonda sobre `git show HEAD:Services/Theme.qml` ignora la variable neutra y coincide con el código nuevo en la histórica: el rung neutro es nuevo y la retrocompatibilidad se sostiene.
- [x] 1.4 Documentar las dos claves en el comentario de cabecera de `Theme.qml`, reemplazando la mención a `moonarch` como si fuera fija.

## 2. El comando de temas

- [x] 2.1 Reemplazar el literal hardcodeado de `Launcher.qml` por el valor resuelto.
  - Verificación estática ejecutada: `grep -n "theme-selector" Modules/Launcher/Launcher.qml` no devuelve nada (exit 1); el default vive en `Theme.defaultThemeCommand`.
- [x] 2.2 Implementar la degradación de D4: si el comando está vacío o no existe (`Quickshell.env`/`FileView`/chequeo de existencia), el modo Themes lista los directorios de `themesRoot` en modo lectura y muestra un mensaje que explica que aplicar requiere un proveedor.
  - Implementado con sonda `FileView` + `find` sobre la raíz resuelta; cubierto por el contrato de 4.2. La verificación en vivo (abrir el modo Themes con un path inexistente) queda como verificación manual pendiente, junto con 2.3.
- [x] 2.3 Verificar que el modo Themes sigue aplicando correctamente con el proveedor real: `qs -c selene ipc call selene openThemes`, elegir un bundle, y ver el cambio aplicado.
  - Verificado en vivo el 2026-09-16 (máquina con compositor, shell corriendo el candidato): aplicado `catppuccin-mocha` por el proveedor (`theme-selector --apply catppuccin-mocha`, el mismo argv que ejecuta `applyTheme()` del launcher), el púrpura del dashboard pasó de `#bb9af7` (6 px de núcleo exacto) a `#F5C2E7` (6 px) y el fondo del panel de `#1A1B26` a `#11111B`; el log de la instancia viva registró `paleta aplicada — bg #11111b accent #a6adc8`. Al volver a `tokyo-night` el púrpura volvió a `#bb9af7` (6 px). Límite declarado: no hay inyección de teclado en la sesión, así que el apply se ejecutó por el proveedor y no con Enter sobre la fila de la UI; el modo Themes sí se abrió por IPC y se capturó listando los 12 bundles.

## 3. El override y su recarga

- [ ] 3.1 Agregar `overrideView.reload()` a `reloadTheme()` (D6).
  - El fix está implementado (`reloadTheme()` recarga los tres `FileView`) y la regresión está fijada por el contrato 4.3. La sintomatología en vivo (ventana de hasta 1 s con paleta mezclada) **solo es observable cuando un bundle empaqueta `quickshell.json`**, y ningún bundle de moonarch lo trae todavía: es el ítem del roadmap del lado de moonarch. Por eso queda sin tildar con motivo, no por falta de evidencia del fix.
  - Observación en vivo (2026-09-16, sin `quickshell.json`): el proveedor llama `qs -c selene ipc call selene themeReload` al aplicar y la paleta convergió completa antes de la primera captura (+0,6 s), sin ventana mezclada visible. Eso ejercita el camino de `reloadTheme()`, pero el síntoma de D6 sigue necesitando un bundle con `quickshell.json`.
- [x] 3.2 Revisar el orden de aplicación para que el ciclo converja en una sola aplicación por cambio: hoy cada `onLoaded` de los tres `FileView` llama a `applyTheme`, así que un cambio dispara hasta tres aplicaciones. Evaluar si conviene agrupar o debouncear, y anotar la decisión en `design.md`.
  - Decisión: agrupación con `Qt.callLater` (sin debounce); anotada en `design.md`.
- [x] 3.3 Confirmar el comportamiento con el fragmento ausente (el caso de hoy): la derivación sigue igual y `_lastOverride` queda en `null` sin loguear ruido.
  - Verificado en runtime con la sonda aislada: con un bundle sin `quickshell.json` el log de overrides aparece 0 veces y la derivación se aplica completa; con el fragmento presente el log aparece y sus tokens ganan por token. Sin ruido en el caso ausente.

## 4. Contratos de test

- [x] 4.1 Agregar a `tests/test_selene_corrections.py` un contrato que assertea que **el comando de temas no es un literal hardcodeado** en `Launcher.qml`, y que la resolución pasa por una fuente configurable.
- [x] 4.2 Agregar un contrato para la degradación: que el modo Themes contempla el caso "sin comando" sin quedar en `themesLoading` (mismo estilo que `test_theme_loading_clears_stale_results_and_blocks_acceptance`).
- [x] 4.3 Agregar un contrato para el override: que `reloadTheme()` recarga los **tres** `FileView`, no dos. Es la regresión de D6 y es exactamente lo que un test estructural puede fijar.
- [x] 4.4 Correr la suite completa: `python3 -m pytest tests/ -q` (o `python3 -m unittest discover -s tests`) sin regresiones.
  - Nota: `pytest` no está instalado en este entorno; se corrieron los cuatro archivos de la suite por separado con `python3 tests/<suite>.py`, todos OK (37 + 6 + 6 + 4 tests).

## 5. Verificación end-to-end

- [x] 5.1 Con `themeCommand` ausente, `themesRoot` válido: Themes lista en modo lectura, el resto de la shell arranca normalmente, y la paleta sale de la derivación de siempre.
  - Verificado en vivo el 2026-09-16: con `SHELL_THEME_COMMAND=/ruta/que-no-existe` el modo Themes abre, lista los 12 bundles de la raíz real y muestra `Listing themes read-only: applying requires a theme provider`, sin quedar en `themesLoading`; el resto de la shell arranca normal. Segunda pasada con `SHELL_THEMES_ROOT=/tmp/verify-root` (3 directorios y un symlink `current`): la lista mostró exactamente esos 3 nombres y excluyó `current`, lo que prueba que la rama de listado usa la raíz **resuelta** (`Theme.themesRoot`) y no la referencia indefinida que tenía el bug de D4.
- [x] 5.2 Con todo en default (moonarch presente): comportamiento idéntico al de hoy, colores incluidos. Comparar contra una captura previa del `bg`/`accent` derivados.
  - Verificado comparando la paleta derivada por el working tree contra la de `HEAD` en la misma sonda aislada y sin configuración: idénticas (`bg #1a1b26`, `accent #7aa2f7`, `purple #bb9af7` y el resto de los tokens). El cambio no toca ningún módulo que renderice la paleta, así que la equivalencia queda probada a nivel de derivación, no por captura visual.
  - A/B en vivo el 2026-09-16 contra la copia instalada de `main` (`6ea82b1`), mismo tema y misma pantalla: barra 27 píxeles distintos de 2.073.600 (solo dígitos de CPU/RAM/reloj), dashboard 218 (solo números dinámicos) y chrome del launcher (tabs y pie) 0 píxeles distintos; el top de colores es idéntico (`#171821` en la barra, `#1A1B26` en el dashboard). El contenido de la lista de apps varió entre corridas porque `DesktopEntries.applications.values` carga asíncrono —se comprobó que varía incluso entre dos aperturas de la misma instancia de `main`—, no por este change.
- [x] 5.3 Con `quickshell.json` presente en un bundle (crear uno de prueba **fuera** del repo de moonarch, por ejemplo en un root temporal): los tokens del JSON ganan, y ausente el JSON la shell sigue igual.
  - Verificado en la sonda aislada con un root temporal fuera del repo de moonarch: con el fragmento presente ganan sus tokens (`bg #2a2a2a`, `accent #2a2aaa`, `purple #7020a0`, `cyan #20a0a0`, `urgent #a02020`) y los que no define siguen derivados del bundle; sin el fragmento, derivación normal. Una clave desconocida no rompe nada.
- [x] 5.4 Arranque con el root apuntando a un directorio inexistente: la shell arranca con el fallback embebido y no se cuelga (esto ya lo cubre el requirement de fallback; se verifica que este cambio no lo rompió).
  - Verificado en la sonda aislada: con `SHELL_THEMES_ROOT=/tmp/tsd-does-not-exist` la shell arranca, reporta la raíz configurada y aplica el fallback embebido, sin cuelgue ni error.

## 6. Cierre

- [ ] 6.1 Archivar este change y sincronizar el delta en `openspec/specs/theme-system/spec.md`.
  - Pendiente: requiere editar `openspec/specs/theme-system/spec.md`, fuera de las superficies de edición autorizadas de esta implementación. El fix deliberado del header MODIFIED del delta ya está en el working tree para permitir el archivo.
- [ ] 6.2 Actualizar `ROADMAP.md`: marcar el contrato como hecho y dejar anotado qué queda del lado de moonarch (empaquetar `quickshell.json` en los 13 bundles, y la rama de reload de Waybar en `theme-selector`).
  - Pendiente: requiere editar `ROADMAP.md`, fuera de las superficies de edición autorizadas.
- [ ] 6.3 Bump del pin del submódulo en `MoonArch` cuando esto se publique, con su PR.
  - Fuera de alcance por diseño: depende de la publicación de este change.

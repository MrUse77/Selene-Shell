# Tasks: declarar la geometría de overlays y popups (Selene#8, segunda mitad)

## Goal

Cerrar #8: que las superficies que flotan alrededor de la barra — OSD, dashboard,
calendario, historial y notificaciones — dejen de tener offsets calibrados y los
deriven de la geometría declarada, sin mover un píxel del layout actual cuando no
hay configuración.

## Context

- Rama `feat/overlay-geometry`, worktree `/home/agustin/Dev/Lab/QML-worktrees/overlay-geometry`,
  creada desde `main` (`7a5a542`, que ya incluye la primera mitad: `Services/Geometry.qml`,
  `Services/GeometryLogic.js` y la barra consumiéndolos).
- Literales a eliminar (verificados en este worktree, 2026-09-22):
  - `Modules/Osd/Osd.qml:17` — `margins.bottom: 90`.
  - `Modules/Dashboard/Dashboard.qml:28-32` — `top: 56`, `right: 14`, `bottom: 14`.
  - `Modules/Bar/CalendarPopup.qml:28-31` — `top: 58`, `right: 18`.
  - `Modules/Bar/HistoryPopup.qml:26-29` — `top: 58`, `right: 18`.
  - `Modules/Notifications/Notifications.qml:30-33` — `top: 60`, `right: 18`.
- Los cinco son copias encadenadas a la barra: con los defaults de la primera
  mitad (`barMarginTop 10`, `barHeight 44`, `barMarginSide 14`) se cumple
  `56 = 10 + 44 + 2`, `58 = 10 + 44 + 4`, `60 = 10 + 44 + 6` y `18 = 14 + 4`.
  Nadie lee la geometría de la barra: los cinco repiten la suma.
- Los cinco módulos son `ExclusionMode.Ignore` (no reservan zona), así que su
  posición es absoluta respecto del monitor: no hay apilado del compositor que
  los afecte (a diferencia del probe de la primera mitad, que aterrizó en `y=64`).
- Instrumento de validación ya probado en la primera mitad: `qs -p` sobre el
  worktree (instancia aparte, no toca el `qs -c selene` vivo) + `hyprctl layers -j`
  para enteros exactos + captura por firma de color de la cápsula.

## Decisions

- **Lo declarable nuevo es uno solo**: `osdMarginBottom` (90), clave
  `osdMarginBottom` en `shell.json` y env `SHELL_OSD_MARGIN_BOTTOM`. El resto de
  los offsets **no** se declaran: se derivan de la geometría de la barra más un
  gap que es decisión de diseño, no supuesto de máquina.
- **El gap de diseño vive en el módulo, con nombre.** Cada consumidor declara su
  propio `gapBelowBar` (2 en dashboard, 4 en calendario e historial, 6 en
  notificaciones) y los popups alineados a la derecha un `rightInset` (4). Así el
  número absoluto sale de la cadena declarada y lo único local es la decisión
  estética, visible y nombrada.
- **La aritmética es pura y testeable**: `GeometryLogic.panelTop(marginTop,
  barHeight, gap)` y `GeometryLogic.panelRight(marginSide, inset)`; el servicio
  las expone ya atadas a los valores declarados (`Geometry.panelTop(gap)`,
  `Geometry.panelRight(inset)`).
- **El dashboard usa `barMarginSide` directo** para sus márgenes derecho e
  inferior (14), sin inset: es el mismo gap exterior de la barra, no una
  separación respecto de un borde de barra.
- **El OSD no se verifica con píxeles cambiando el volumen**: en el probe se
  instancia el OSD y se lo saca a la luz llamando a su propio `poke()`, así que
  no se toca el volumen del sistema ni suena nada.
- **Notificaciones queda sin medición viva post-cambio.** Montarla en el probe
  pelearía por el nombre DBus de demonio de notificaciones con la shell en uso, y
  detener la shell viva es una decisión del usuario que ya se descartó para esta
  validación. Se cubre con: los contratos de sus valores exactos, el test puro de
  la derivación (gap 6 → 60), y el hecho de que calendario e historial —que sí se
  miden vivos— usan exactamente el mismo patrón de anclaje. Queda declarado como
  límite, no escondido.

## Non-goals

- Rediseñar el OSD o los popups: sólo se mueve de dónde salen sus márgenes.
- Declarar como settings los anchos/altos de las superficies (340, 320, 380, 470),
  los insets internos (14) ni el ancho duplicado de las notificaciones (`:106`).
- Tocar la barra: ya quedó declarada en la primera mitad.
- Cambiar el `openspec/config.yaml` ni el spec canónico de `bar` (misma decisión
  que la primera mitad: pertenece a un `changes/` propio).
- Detener, reiniciar o redeployar `qs -c selene`.

## Tasks

- [x] **T1 — Baseline y contratos primero (rojo).** Probe nuevo en `/tmp/geom2-probe`
      que monta barra + OSD + calendario + historial + dashboard desde este worktree
      y saca a la luz una superficie por corrida según `QS_GEOM_SURFACE`.
      **Hallazgo de instrumento:** la firma de Hyprland había cambiado (la máquina se
      reinició entre las dos mitades), así que hardcodearla rompió la primera corrida;
      ahora el probe descubre firma y PID de la shell viva en runtime. Segundo
      hallazgo, del mismo tipo: `ShellState.toggleCalendar` espera el **nombre** del
      monitor mientras `OverlayCoordinator.resolveFocusedScreen()` devuelve el
      **objeto** — pasarle el objeto no abre nada y no da error.
      Baseline previo (DP-2, enteros del compositor): barra del probe `14,64 1892x44`
      (apilada bajo la zona de la shell viva), calendario `1582,58 320x350`,
      historial `1522,58 380x420`, dashboard `1436,56 470x1010`, OSD `790,934 340x56`.
      Los cinco coinciden exactamente con la aritmética: `58 = 10+44+4`,
      `56 = 10+44+2`, `934 = 1080-90-56`. Notificaciones del shell vivo en `y=60`
      (el literal a reemplazar) como referencia.
      Rojo observado por el implementador: 18 fallos de contrato en la fase de
      servicio (p. ej. `3 != 4 : Geometry.qml debe encadenar exactamente una llamada a
      Theme.pick por valor declarado`), la suite QML con `Property 'panelTop' of
      object [object Object] is not a function`, y 13 fallos de consumidor en la fase
      de módulos (`{'top': '56', 'right': '14', 'bottom': '14'} != {'top':
      'Geometry.panelTop(gapBelowBar)', ...}`).

- [x] **T2 — Aritmética y cadena del OSD (verde).**
      `GeometryLogic.panelTop(marginTop, barHeight, gap)` y `panelRight(marginSide,
      inset)` (puras, sin acotar: suman valores ya validados), `Geometry.panelTop`/
      `Geometry.panelRight` atadas a los valores declarados, `defaultOsdMarginBottom:
      90` + la cadena de `osdMarginBottom`, `Theme.settingsOsdMarginBottom` y la clave
      en `shell.json`.
      Evidencia: python `Ran 84 tests / OK` (baseline 81); QML
      `16 / 10 / 11 / 41` sin fallos (la suite de geometría pasó de 8 a 10 casos);
      `qmllint --missing-property error` 49 archivos, exit 0, mismas 57 ocurrencias
      de `Warning:` que el árbol prístino.

- [x] **T3 — Los cinco consumidores.** OSD `margins.bottom: Geometry.osdMarginBottom`;
      dashboard con `gapBelowBar: 2` y márgenes derecho/inferior en `barMarginSide`;
      calendario e historial con `gapBelowBar: 4` y `rightInset: 4`; notificaciones con
      `gapBelowBar: 6` y `rightInset: 4`. Ningún bloque `margins` conserva un literal
      absoluto.
      Evidencia de mutación (copias en `/tmp`): bajar el gap de `panelTop` falla
      `test_panel_top_adds_the_design_gap_below_the_bar` (`Actual (): 54 / Expected
      (): 56`); cambiar el margen derecho del dashboard por un
      `panelRight(0)` numéricamente idéntico falla el contrato de rol; y subir
      `gapBelowBar` de 4 a 5 en el calendario falla dos contratos, incluido
      `59 != 58 : CalendarPopup.top: con los defaults declarados (44/10/14) el offset
      derivado debe igualar el literal previo 58`. Hallazgo honesto: intercambiar los
      sumandos de `panelTop` es **invisible** para cualquier test porque la suma es
      conmutativa; el control no conmutativo (quitar el gap) sí falla.

- [x] **T4 — Verificación visual A/B.** Dos corridas del probe (post-cambio y con
      `SHELL_BAR_HEIGHT=60`) contra el baseline.
      Geometría del compositor, idéntica en el caso default: calendario `1582,58
      320x350`, historial `1522,58 380x420`, dashboard `1436,56 470x1010`, OSD
      `790,934 340x56`.
      Píxeles, pre vs post (borde renderizado de cada plataforma): calendario 64 y 64,
      historial 64 y 64, dashboard 65 y 65, y el borde inferior del OSD clavado en
      **989 en las tres corridas** (pre, post y con la barra a 60 — el OSD no depende
      de la barra). La tarjeta visible queda inset respecto de su ventana, por eso la
      fila absoluta no coincide con el `y` del compositor: lo que prueba paridad es la
      igualdad, no el número suelto.
      Control positivo de la cadena: con `SHELL_BAR_HEIGHT=60` la barra mide 60 y los
      paneles siguen su borde inferior nuevo — calendario e historial a `y=74`
      (`10+60+4`), dashboard a `y=72` (`10+60+2`, alto 994 = `1080-72-14`), y el OSD
      sin moverse. En píxeles ese caso no es separable (los paneles quedan dentro del
      alto de la barra y comparten el relleno), así que ahí manda el compositor.
      Incidente registrado: una de las corridas del caso OSD murió con segfault (11) en
      el *apagado* del probe, con `FileView` pendientes; tres repeticiones posteriores
      salieron limpias y con la geometría correcta, así que es un defecto del arnés de
      sondeo, no del cambio. La shell viva (PID 1886) siguió en pie en todas las
      corridas.

- [x] **T5 — Roadmap.** `ROADMAP.md` registra #8 como declarado entero: las claves de
      la barra, `SHELL_OSD_MARGIN_BOTTOM`/`osdMarginBottom` para el OSD y la
      derivación de los overlays por gap de diseño, con el efecto buscado (cambiar el
      alto de la barra los mueve a todos).
      Evidencia: los gates no dependen de docs; la corrida completa sigue en verde

## Follow-ups arrastrados (no son tareas de este cambio)

- Los cinco hallazgos advisory del review nativo de la primera mitad
  (`odd/tasks/panel-geometry.md`), ninguno bloqueante.
- El reviewer del review nativo no puede ejecutarse con los lentes en
  `opencode-go` (falta el header `x-opencode-session` en el side-call): con el
  ruteo tal como está, la review de esta mitad va a fallar igual.

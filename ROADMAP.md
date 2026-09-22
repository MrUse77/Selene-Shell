# ROADMAP — Selene

> Nota de dirección, no especificación. Lo que es comportamiento presente vive en
> `openspec/specs/`; lo que es trabajo en curso vive en `openspec/changes/`. Esto
> existe para que una sesión nueva entienda **por qué** hacemos lo que hacemos y
> qué falta, sin tener que reconstruir la conversación que lo decidió.

## Dónde nos paramos

Selene es una **shell**, no una distro. La distinción no es semántica: define qué
le toca a cada lado y qué se puede cambiar sin romper al otro.

La posición objetivo es **entre Caelestia y Omarchy**, y conviene ser preciso
sobre qué tomamos de cada uno, porque son apuestas distintas sobre el mismo
sustrato (Arch + Hyprland + un CLI).

| | Caelestia | Omarchy | Selene + MoonArch |
| --- | --- | --- | --- |
| Qué es | una shell, con sus dots aparte | una distribución entera | una distro con la shell como componente de primera clase |
| Empaquetado | shell propio (AUR, Nix), instalable solo | distro completa | **pendiente** |
| Config | `shell.json` propio, con `paths.*` | — | **hecho**: `shell.json` propio con `themesRoot` y `themeCommand` |
| Temas | esquema derivado del fondo de pantalla | manual de "hacé tu propio tema" | bundles + contrato de fragmentos, **a publicar** |
| Rollback | — | **snapshots de sistema** | **por target**, con journal y digests |
| Hardware | — | **decenas de scripts `omarchy-hw-*`** | declarar defaults, no adivinar |

### Lo que tomamos de Caelestia

Que **la shell es un artefacto propio**: repo propio, config propia con paths
configurables, y una relación con la distro que la *incluye* en vez de ser su
requisito. Caelestia lo dice explícito en su README (*"this repo is for
Caelestia's desktop shell only"*) y lo respalda con AUR, Nix, `caelestia-cli` y
`~/.config/caelestia/shell.json`.

Eso es lo que el change `theme-source-decoupling` está implementando: Selene
resuelve una raíz de temas y un comando de temas **configurables, con moonarch
como default y no como requisito**.

### Lo que tomamos de Omarchy

Que **es una distro de verdad**: se instala, y a cambio te queda un escritorio
opinionado y funcionando. Eso es el objetivo lejano, y no se llega por features
sino por tres cosas que Omarchy tiene y nosotros no:

1. **un manual** — 51 capítulos con capturas, espejado en un sitio;
2. **manejo por hardware** — decenas de scripts, uno por excepción;
3. **un flujo de instalación para extraños**.

### Lo que decidimos NO tomar

**La cola por hardware.** Es la tentación obvia y es una **cola de mantenimiento
ilimitada**: cada laptop nueva del mundo es un bug potencial nuestro. Omarchy la
paga con decenas de scripts y con ser su trabajo de tiempo completo.

Nuestra alternativa es la misma disciplina que este change: **declarar defaults
en vez de adivinar**, y que quien instala ajuste en vez de que nosotros
sospechemos. Una instalación que declara monitores, gaps y perfiles como
configuración explícita con default sirve hoy, y no compra la cola infinita.

## Los dos ejes

### (a) De "mis dotfiles" a "una distro configurable"

Los cuatro objetivos de `MoonArch/MoonArch.md` están casi todos construidos
(actualizar el CLI sin cambiar el escritorio, fijar una versión de configs, volver
a una edición anterior, recuperar estado local). Lo que falta es la capa de
producto:

- **Perfiles** — "minimal" vs "full" en vez de un set fijo de grupos. La
  maquinaria de grupos y exclusiones ya existe.
- **Formato de temas público y documentado** — hoy el contrato de bundles existe
  pero no está escrito para terceros. Documentarlo convierte a otros en
  contribuyentes. **Precedente: Omarchy documenta `making-your-own-theme`.**
- **Bootstrap que no asuma ninguna máquina** — hoy asume la del autor.

### (b) La shell como componente de primera clase

Selene con cadencia propia y un contrato de fragmentos publicado. Este eje ya está
tomado: es submódulo de MoonArch, tiene su propio `openspec/`, y el change activo
es precisamente su contrato.

### Por qué (a) y (b) son **una sola** inversión

El "formato de temas público" de (a) y el "provider contract" de (b) son **el
mismo artefacto visto de dos lados**: el formato es lo que un proveedor consume,
el contrato es quién lo consume. Documentarlos juntos produce una cosa — un
contrato — y ese contrato es lo que permite que otros hagan temas y shells sin que
los mantengamos nosotros. Es el eje que **compone**; el multi-escritorio es el que
**multiplica**.

## Qué falta, y de qué lado

### De este lado (Selene)

- [x] **`theme-source-decoupling`** — implementado, verificado en vivo y archivado el
      2026-09-16. El contrato vive en `openspec/specs/theme-system/spec.md` y el
      registro en `openspec/changes/archive/2026-09-16-theme-source-decoupling/`.
      Queda sin verificar en vivo el síntoma de D6 (ventana de paleta mezclada)
      porque necesita un bundle que empaquete `quickshell.json`: es el ítem de
      moonarch de abajo.
- [x] **CI** — implementado. `.github/workflows/ci.yml` corre cuatro jobs en cada
      push a `main` y en cada PR: contratos Python, tests QML con `qmltestrunner`
      headless (los tres suites son lógica pura: no necesitan compositor), lint de
      QML/JS con `qmllint` y validación de los propios workflows con actionlint.
      El gate de lint falla ante `missing-property`, no solo ante errores: esa
      categoría es la que dejó pasar un `Theme.settings` inexistente que rompía en
      silencio la lectura de `shell.json`. Quedan afuera el formateo automático
      (`qmlformat`) y el release, que dependen de que exista algo que empaquetar.
- [ ] **Empaquetado propio** (#14). Sin build system ni releases: hoy la única
      forma de obtener Selene es el submódulo de MoonArch. Caelestia se instala
      solo (AUR, Nix). Sin esto, "artefacto propio" queda a medias.
- [ ] **Multi-monitor y hardware** — **en curso**. Un relevamiento de supuestos de
      máquina encontró varios que degradan según el hardware, y los tres que
      fallaban en silencio ya están resueltos: la temperatura leía el primer
      `hwmon` del sistema (en este equipo, la del NVMe en vez de la del CPU) y
      ahora se autodetecta por nombre de sensor y es declarable; los workspaces por
      monitor dejaron de ser un 5 fijo; y un chequeo de updates imposible ya no se
      confunde con "estás al día".
      Los estados quedaron expuestos para diagnóstico, pero **ningún widget los
      consume todavía**. La geometría (#8) quedó declarada entera: la barra tiene su
      alto y sus márgenes por la cadena de siempre (`SHELL_BAR_HEIGHT`,
      `SHELL_BAR_MARGIN_TOP`, `SHELL_BAR_MARGIN_SIDE`, o `barHeight`,
      `barMarginTop` y `barMarginSide` en `shell.json`), su zona exclusiva se deriva
      de la altura, y el OSD declara su distancia al borde inferior
      (`SHELL_OSD_MARGIN_BOTTOM` / `osdMarginBottom`, default 90). Los overlays y
      popups ya no repiten esa geometría: la derivan de la barra más un gap de
      diseño que cada módulo declara con nombre, así que cambiar el alto de la barra
      los mueve a todos. Sin configuración el layout es idéntico al previo.
      Falta: comandos de herramientas (#9), identidad y locale (#10) y la UI que
      haga visibles esos estados (#11).

### Del otro lado (MoonArch), para que el contrato cierre

- [ ] **Empaquetar `quickshell.json` en los 13 bundles** (MoonArch#139) — el
      fragmento dedicado que Selene ya sabe leer con prioridad total. Hoy no existe
      en ningún bundle, así que el hook está dormido y el último síntoma de D6
      (hasta 1 s de paleta mezclada al re-temar) todavía no se puede observar en
      vivo.
- [ ] **Arreglar la rama de reload de Waybar** en `theme-selector`
      (MoonArch#140) (`pgrep -x waybar` / `pkill -SIGUSR2 waybar`): es un rastro
      del stack retirado, y sacarlo necesita delta del spec de
      `moonarch-theme-selector`. El mismo script ya llama
      `qs -c selene ipc call selene themeReload` al aplicar, que es el camino por
      el que Selene converge al instante.
- [ ] **Borrar `cli/pkg/installer/packages.go`** (MoonArch#141) — lista muerta con
      waybar, wofi, dunst, `aur/eww` y `aur/wlogout`, con cero callers.

## Línea de deprecación

Decisión del autor, y el timing está bien elegido: `RELEASING.md` permite cambios
incompatibles como MINOR mientras el proyecto esté en `0.x`, pero **después de
`1.0.0` sacar un fragmento del contrato cuesta un MAJOR**. `1.0.0` es la última
ventana de limpieza gratis.

| Momento | `quickshell.json` | `waybar.css` |
| --- | --- | --- |
| **Ahora** (`config-v0.x.y`) | opcional; se empaqueta y Selene lo prefiere | sigue siendo el fragmento de derivación |
| **En `1.0.0`** | **requerido** en el contrato | **sale del contrato**: los 13 archivos mueren |

Cuando se ejecute el lado de `1.0.0`, el fragmento de nombre histórico deja de
existir y con él el último rastro de la herramienta que lo nombró. Hasta entonces,
la rama de fallback de Selene es lo que hace que la transición no rompa bundles
publicados.

## El criterio de la puerta

El objetivo lejano ("distro tipo Omarchy") deja de ser lejano cuando **el proyecto
no asume ninguna máquina en particular**. Hoy asume la del autor: dos monitores,
sin batería, AMD, `gaps_out = 15`, y un checkout de desarrollo en `~/Dev/Lab/QML`.

Ese es el criterio a mirar, no la cantidad de features.

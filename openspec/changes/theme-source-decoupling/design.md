# Design: theme-source-decoupling

## Context

Selene es una **shell**, no una distro. Su línea de descendencia —nació como derivación de Caelestia— lo confirma, y Caelestia lo dibuja explícitamente: su repositorio es *"for Caelestia's desktop shell only"*, sus dots viven en otro repo, el shell se empaqueta y se instala solo (AUR, Nix), tiene su **propio CLI** (`caelestia-cli`) y su **propio archivo de config con paths configurables** (`~/.config/caelestia/shell.json`, con cosas como `paths.wallpaperDir`).

En ese modelo, moonarch es el equivalente de los *dots*: la distro que **incluye** la shell. Y ahí aparece el problema real de este cambio: `Services/Theme.qml` y `Modules/Launcher/Launcher.qml` no leen "una raíz de temas" y "un comando de temas" — leen rutas absolutas de la distro. Es un error de categoría respecto de la propia genealogía de Selene.

El acoplamiento, medido, son **dos puntos**:

| Punto | Código | Estado |
| --- | --- | --- |
| Raíz de temas | `Theme.qml`: `MOONARCH_THEMES_ROOT ?? $HOME/.local/share/moonarch/themes` | tiene escape por env var; el nombre y el default son de moonarch |
| Comando de temas | `Launcher.qml`: `$HOME/.local/bin/moonarch/theme-selector` | hardcodeado, sin override |

El resto de las menciones a moonarch en el código son comentarios.

Y el requisito real de Selene no es "moonarch": es **una raíz con fragmentos de color** y **un comando que liste ids y aplique uno**. Esa interfaz ya existe — es `--list` / `--apply`. El acoplamiento es de nombres y defaults, no de diseño, y por eso se resuelve chico.

## Goals / Non-Goals

**Goals**

- Que la raíz de temas y el comando de temas sean **configurables con los valores de moonarch como default**, no como requisitos.
- Que Selene **degrade legiblemente** sin proveedor de temas, en vez de dejar un modo Themes muerto.
- Dejar el contrato del fragmento dedicado (`quickshell.json`) especificado, porque hoy existe en el código y **no está en ningún spec**.
- Corregir el defecto de recarga del override, que **se arma solo** cuando moonarch empaquete el fragmento.

**Non-Goals**

- **Mover la gestión de temas adentro de Selene.** Validar, swapear atómicamente y restaurar ante un reload fallido es rol de la distro (hoy `moonarch/theme-selector`, con suite de tests y spec propios). Reimplementarlo en QML/JS sería que la shell se meta en el rol de la distro, y es donde viven los bugs de un tema a medio aplicar.
- **Renombrar `waybar.css`.** El fragmento dedicado lo deprecia sin cirugía coordinada entre repos y sin riesgo de falla silenciosa.
- **Instalar o descubrir proveedores.** Selene consume el que le configuren; no busca alternativas.

## Decisions

### D1: El default sigue siendo moonarch

El objetivo es que deje de ser requisito, no sacarle la integración: Selene *es* la shell de moonarch. Un default neutro obligaría a configurar a mano en el caso principal, que es el 100% de los casos hoy. La diferencia entre **default** y **requisito** es todo este change.

### D2: `ShellSettings` como fuente, con precedente

`shell.qml` ya tiene `settings.watchFiles: true`, o sea que el sistema de `ShellSettings` de Quickshell está activo y sin usar. Declarar ahí `themesRoot` y `themeCommand` es exactamente el patrón que Caelestia usa para lo mismo (`shell.json` con `paths.*`): **la shell tiene su propio archivo de config y sus propios defaults.**

Las variables de entorno quedan como **override de sesión**, en el orden que ya existe hoy (env primero), para poder arrancar una variante sin editar archivos — que es como se testea.

### D3: Cadena de resolución explícita, con alias de compatibilidad

```
themesRoot:   env SHELL_THEMES_ROOT   → env MOONARCH_THEMES_ROOT   → setting   → default moonarch
themeCommand: env SHELL_THEME_COMMAND → env MOONARCH_THEME_COMMAND → setting   → default moonarch
```

El nombre nuevo no menciona moonarch; el viejo queda como alias para no romper ningún setup existente, incluida la máquina del autor hoy. La verificación de la API exacta de `ShellSettings` en la versión instalada queda como tarea, porque no se puede asumir de memoria.

### D4: El comando de temas, con degradación legible

Si `themeCommand` está vacío o no existe, el modo Themes **lista los directorios de `themesRoot` en modo lectura** y explica que aplicar requiere un proveedor. No falla y no queda inerte: muestra lo que hay y dice qué falta. Un modo que existe pero no hace nada es peor que uno que explica por qué no puede.

### D5: `quickshell.json` opcional ahora, requerido en 1.0

Decisión del autor, y el timing está bien elegido: `RELEASING.md` permite cambios incompatibles como MINOR mientras el proyecto esté en `0.x`, pero **después de `1.0.0` sacar un fragmento del contrato cuesta un MAJOR**. `1.0.0` es la última ventana de limpieza gratis.

- **Ahora**: el fragmento es **opcional**. Selene le da prioridad total si existe y sigue con la derivación si no, así que los bundles publicados sin él siguen funcionando.
- **En 1.0**: `quickshell.json` pasa a **requerido** y `waybar.css` **sale del contrato**. Los 13 archivos del nombre viejo mueren ahí, y con ellos este acoplamiento.

La obligatoriedad futura **no se especifica como requirement** — un spec describe comportamiento presente, no planes. Va en `ROADMAP.md` y en el follow-up de este change, y el cambio que la ejecute trae su propio delta.

### D6: El override tiene un defecto de recarga que hay que cerrar ANTES

`overrideView` lo recarga el poll de 1 s, pero **`reloadTheme()` no** — y esa es la ruta del IPC `themeReload`:

```
reloadTheme()  → ghosttyView.reload() + waybarView.reload()      ← falta overrideView
Timer (1 s)    → los tres                                        ← acá sí
```

Con `quickshell.json` presente: cambiás de tema, ghostty y waybar recargan al instante, y `applyTheme` aplica el `_lastOverride` **del bundle anterior** encima de la paleta nueva. Resultado: hasta 1 s de **paleta mezclada** hasta que el poll corrige.

Hoy es invisible porque ningún bundle tiene el archivo. Es una mina que **se arma sola** el día que moonarch lo empaquete, y por eso es tarea de este change y no del que lo consuma.

### D7: Los tests de contrato tienen que acompañar

La suite de Selene son **contract tests estructurales**: leen el código fuente y assertean patrones con regex. Eso da una forma barata de fijar este cambio, y conviene usarla: un test que assertea que **el path no está hardcodeado** es exactamente el tipo de contrato que la suite ya sabe expresar.

## Impact

- **Código**: `Services/Theme.qml` (resolución + recarga del override), `Modules/Launcher/Launcher.qml` (comando + degradación).
- **Sin cambios de comportamiento por defecto**: con la configuración actual Selene resuelve los mismos valores que hoy, y los mismos colores.
- **MoonArch**: no necesita cambios para que esto funcione. Lo que sí necesita, como trabajo propio y posterior, es empaquetar `quickshell.json` en los 13 bundles y arreglar la rama de reload de Waybar en `theme-selector`.
- **Compatibilidad**: los setups que ya usan `MOONARCH_THEMES_ROOT` siguen funcionando sin tocar nada.

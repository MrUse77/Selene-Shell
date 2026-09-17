# Proposal: theme-source-decoupling

## Why

Selene está diseñada como la shell de moonarch, y eso está bien: es su caso principal. Pero hoy esa relación es un **requisito**, no un default, en dos puntos concretos del código:

- `Services/Theme.qml` resuelve la raíz de temas como `MOONARCH_THEMES_ROOT ?? $HOME/.local/share/moonarch/themes`. Tiene escape por variable de entorno, pero el nombre y el default son de moonarch.
- `Modules/Launcher/Launcher.qml` hardcodea `$HOME/.local/bin/moonarch/theme-selector`, sin override. Sin moonarch, el modo Themes del launcher queda muerto.

La consecuencia práctica: no se puede correr Selene contra otra fuente de temas ni sin moonarch instalado, aunque la cadena de derivación ya degrada sola a la paleta embebida.

El requisito real de Selene no es "moonarch": es **una raíz con fragmentos de color** y **un comando que liste ids y aplique uno**. Esa interfaz ya existe — es `--list` / `--apply`. El acoplamiento es de nombres y defaults, no de diseño, y por eso se puede resolver chico.

El `config.yaml` de este repo ya anticipa este trabajo: *"la integración oficial con moonarch se planifica en changes aparte"*.

## What Changes

- **Raíz de temas configurable**: se declara como setting de Quickshell, con el valor de moonarch como **default**, y una variable de entorno de nombre neutro como override de sesión. `MOONARCH_THEMES_ROOT` se conserva como alias de compatibilidad.
- **Comando de temas configurable**: el launcher deja de hardcodear `moonarch/theme-selector` y lo lee de la misma fuente de configuración, con el valor actual como default.
- **Degradación legible**: si no hay comando de temas disponible, el modo Themes lista los directorios de la raíz en modo lectura y explica que aplicar requiere un proveedor, en vez de fallar o quedar inerte.
- **Sin duplicar la gestión de temas**: Selene sigue sin validar, swapear ni restaurar temas. Eso queda del lado del proveedor (hoy `moonarch/theme-selector`), que ya tiene suite de tests y spec propios.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `theme-system`: la derivación deja de estar atada a una ruta absoluta de moonarch y pasa a resolver una raíz configurable. Se agrega además el contrato de la fuente de temas intercambiable (raíz + comando) y su degradación sin proveedor.

No se toca `launcher`: el modo Themes no está especificado hoy en ninguna capability, ni sincronizada ni pendiente, y este change no introduce su contrato visual sino el de la fuente que consume. Si más adelante se quiere especificar el modo, va en su propio cambio.

## Impact

- **Código afectado**: `Services/Theme.qml` (resolución de la raíz), `Modules/Launcher/Launcher.qml` (comando + degradación del modo Themes).
- **Sin cambios de comportamiento por defecto**: con la configuración actual, Selene resuelve exactamente los mismos valores que hoy.
- **Sin impacto en moonarch**: el repo de dotfiles no necesita cambios salvo el bump del pin cuando Selene publique esto. `theme-selector` queda como está.
- **Compatibilidad**: los setups que ya usan `MOONARCH_THEMES_ROOT` siguen funcionando sin tocar nada.

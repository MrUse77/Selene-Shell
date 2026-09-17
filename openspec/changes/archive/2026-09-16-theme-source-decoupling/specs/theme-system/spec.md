# Delta for theme-system

## MODIFIED Requirements

### Requirement: Derivar paleta desde el bundle activo de moonarch

El sistema SHALL derivar la paleta de colores leyendo `<raíz de temas>/current/ghostty.conf` (colores ANSI 0–15, background, foreground) y completar acentos con `<raíz de temas>/current/waybar.css` cuando esté disponible, donde `<raíz de temas>` es el valor resuelto según el requirement de fuente de temas configurable. Los tokens derivados (fondo, superficies, texto, acento, urgentes, glow) MUST ser consumidos por todos los módulos, sin colores hardcodeados por módulo.

#### Scenario: Bundle válido presente

- **WHEN** el symlink `current` de la raíz de temas apunta a un bundle con `ghostty.conf` parseable
- **THEN** la shell renderiza todos sus módulos con la paleta derivada de ese bundle

#### Scenario: Acento preferente de waybar.css

- **WHEN** `waybar.css` del bundle define `accent_blue` y `urgent_red`
- **THEN** esos valores tienen prioridad sobre los derivados de la paleta ANSI para acento y urgente

#### Scenario: Raíz alternativa

- **WHEN** la raíz de temas resuelta apunta a un directorio distinto del de moonarch, con la misma estructura de bundles
- **THEN** la shell deriva la paleta de esa raíz sin cambios de código

## ADDED Requirements

### Requirement: Fuente de temas configurable

El sistema SHALL resolver la raíz de temas y el comando de temas desde una fuente configurable, con los valores de moonarch como **default** y no como requisito. La resolución MUST aceptar, en este orden, una variable de entorno de nombre neutro, la variable de entorno histórica de moonarch, el valor configurado en los settings de la shell, y el default. El comando de temas MUST NOT estar hardcodeado en ningún módulo.

#### Scenario: Default sin configuración

- **WHEN** no hay ninguna configuración ni variable de entorno presente
- **THEN** la raíz resuelta es la de moonarch y el comando resuelto es el selector de moonarch, idénticos al comportamiento previo

#### Scenario: Override por variable de entorno

- **WHEN** la variable de entorno de nombre neutro apunta a otra raíz
- **THEN** la shell usa esa raíz, sin editar ningún archivo de configuración

#### Scenario: Compatibilidad con la variable histórica

- **WHEN** sólo está seteada la variable de entorno de moonarch
- **THEN** la shell la respeta y no cae al default

#### Scenario: Sin proveedor de temas disponible

- **WHEN** el comando de temas resuelto está vacío o no existe
- **THEN** el modo Themes lista los bundles de la raíz resuelta en modo lectura y comunica que aplicar requiere un proveedor
- **AND** la shell no falla, no queda en estado de carga y el resto de los modos sigue funcionando

### Requirement: Overrides explícitos por bundle

El sistema SHALL leer, si existe, `<raíz de temas>/current/quickshell.json` como fuente de tokens con **prioridad total** sobre la derivación. Las claves que no correspondan a un token conocido MUST ser ignoradas, y la ausencia o el fallo de parseo del archivo MUST dejar la derivación intacta sin interrumpir el arranque. En esta etapa el archivo es **opcional** en el contrato de bundles.

#### Scenario: Fragmento dedicado presente

- **WHEN** el bundle activo incluye `quickshell.json` con tokens válidos
- **THEN** esos valores tienen prioridad total sobre los derivados de `ghostty.conf` y `waybar.css`

#### Scenario: Claves desconocidas

- **WHEN** el archivo define una clave que no corresponde a ningún token conocido
- **THEN** la clave se ignora y el resto del archivo se aplica

#### Scenario: Fragmento ausente

- **WHEN** el bundle activo no incluye `quickshell.json`
- **THEN** la shell deriva la paleta como siempre y no registra errores

#### Scenario: Re-tema con fragmento presente

- **WHEN** se cambia de bundle y el nuevo también trae `quickshell.json`
- **THEN** la recarga inmediata aplica los tokens del bundle **nuevo**, sin ventana intermedia con los del anterior

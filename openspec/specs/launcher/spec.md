# launcher

## Purpose

Launcher de aplicaciones de Selene: búsqueda fuzzy sobre las entradas de desktop del sistema, navegable por teclado, con cálculo aritmético inline, con apertura animada acorde a la identidad de la shell.

## Requirements

### Requirement: Búsqueda fuzzy de aplicaciones
El sistema SHALL listar las aplicaciones (DesktopEntries no ocultas) filtradas por coincidencia fuzzy sobre nombre y descripción, ordenadas por pertinencia, y lanzar la seleccionada con Enter.

#### Scenario: Búsqueda parcial
- **WHEN** el usuario tipea "gterm" y existe "Ghostty"
- **THEN** Ghostty aparece entre los primeros resultados de la lista

#### Scenario: Lanzar aplicación
- **WHEN** el usuario pulsa Enter con una aplicación seleccionada
- **THEN** la aplicación se lanza y el launcher se cierra

### Requirement: Navegación por teclado
El sistema SHALL permitir mover la selección con las flechas arriba/abajo, confirmar con Enter y cerrar con Escape o al perder el foco de teclado, devolviendo el foco al compositor.

#### Scenario: Cerrar sin lanzar
- **WHEN** el usuario pulsa Escape con el launcher abierto
- **THEN** el launcher se cierra sin lanzar nada y el foco vuelve al escritorio

### Requirement: Cálculo aritmético inline
El sistema SHALL, cuando la consulta comienza con `=`, interpretar el resto como expresión aritmética y mostrar el resultado en vivo; Enter copia el resultado al portapapeles Wayland.

#### Scenario: Expresión válida
- **WHEN** el usuario tipea `=(2+3)*4`
- **THEN** el launcher muestra `20` como resultado y al pulsar Enter lo copia al portapapeles

#### Scenario: Expresión inválida
- **WHEN** el usuario tipea `=2+`
- **THEN** el launcher indica que no hay resultado sin romperse ni cerrarse

### Requirement: Aparición en el monitor enfocado
El sistema SHALL abrir el launcher centrado en el monitor enfocado actualmente, con animación de entrada/salida tipo popin según el sistema de animación de la shell.

#### Scenario: Abrir en monitor derecho
- **WHEN** el monitor enfocado es HDMI-A-1 y se abre el launcher
- **THEN** el launcher aparece centrado en ese monitor

pragma Singleton

import QtQuick
import Quickshell
import "GeometryLogic.js" as GeometryLogic

// Geometría de la barra: alto y márgenes declarados en un solo lugar.
//
// Antes estos números vivían hardcodeados en Modules/Bar/Bar.qml (top: 10,
// left/right: 14, implicitHeight: 44) y estaban repetidos: cambiar el alto de
// la barra obligaba a tocar el literal del alto y el de la zona exclusiva, que
// se desincronizaban en silencio. Ahora cada valor se resuelve por la cadena de
// la casa — env neutra → setting del shell.json → default — y la barra solo los
// consume.
//
// Cadena de cada valor (el primer valor no vacío gana):
//   1. Variable de entorno neutra   SHELL_BAR_HEIGHT / SHELL_BAR_MARGIN_TOP /
//                                   SHELL_BAR_MARGIN_SIDE
//   2. Setting de la shell          barHeight / barMarginTop / barMarginSide
//   3. Default                      el layout histórico de este archivo
//
// El valor crudo llega como string y puede ser basura o un absurdo (una barra de
// 1e9 px), así que el parseo y el acotado viven en GeometryLogic, no acá.
Item {
    id: root

    // Defaults: reproducen el layout histórico exacto, que era el bloque
    // `margins { top: 10; left: 14; right: 14 }` más `implicitHeight: 44` de
    // Bar.qml. Son la única fuente de verdad cuando no hay env ni setting.
    readonly property int defaultBarHeight: 44
    readonly property int defaultBarMarginTop: 10
    readonly property int defaultBarMarginSide: 14

    // Alto de la barra: la env de nombre neutro precede al setting, y el
    // default va último en la cadena.
    readonly property int barHeight: GeometryLogic.resolve(
        Theme.pick(
            Quickshell.env("SHELL_BAR_HEIGHT"),
            Theme.settingsBarHeight,
            ""
        ),
        defaultBarHeight,
        GeometryLogic.MIN_BAR_HEIGHT,
        GeometryLogic.MAX_BAR_HEIGHT
    )

    // Margen superior de la barra respecto del borde del monitor.
    readonly property int barMarginTop: GeometryLogic.resolve(
        Theme.pick(
            Quickshell.env("SHELL_BAR_MARGIN_TOP"),
            Theme.settingsBarMarginTop,
            ""
        ),
        defaultBarMarginTop,
        GeometryLogic.MIN_MARGIN,
        GeometryLogic.MAX_MARGIN
    )

    // Margen lateral: el mismo valor para izquierda y derecha, como antes.
    readonly property int barMarginSide: GeometryLogic.resolve(
        Theme.pick(
            Quickshell.env("SHELL_BAR_MARGIN_SIDE"),
            Theme.settingsBarMarginSide,
            ""
        ),
        defaultBarMarginSide,
        GeometryLogic.MIN_MARGIN,
        GeometryLogic.MAX_MARGIN
    )
}

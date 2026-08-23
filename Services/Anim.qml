pragma Singleton

import QtQuick

// Curvas y duraciones de hyprland.lua (hl.curve / hl.animation),
// replicadas como bezierCurve de QML para que shell y compositor
// se sientan un solo sistema. Duraciones ≈ 1000/speed ms.
QtObject {
    // smooth (0.5,0)(0.5,1) — fades y transiciones generales
    readonly property var smooth: [0.5, 0, 0.5, 1, 1, 1]
    // easeOutQuint (0.23,1)(0.32,1) — layers: popups que suben
    readonly property var easeOutQuint: [0.23, 1, 0.32, 1, 1, 1]
    // overshot (0.13,0.99)(0.29,1.05) — windowsIn popin: launcher
    readonly property var overshot: [0.13, 0.99, 0.29, 1.05, 1, 1]
    // gentle (0.25,0.1)(0.25,1) — workspaces
    readonly property var gentle: [0.25, 0.1, 0.25, 1, 1, 1]

    readonly property int fast: 167    // layersIn(6), border(6)
    readonly property int normal: 222  // windows(4.5), workspaces(4.5)
    readonly property int slow: 250    // layers(4), fade(4)
    readonly property int slower: 300  // drawers y transiciones largas
}

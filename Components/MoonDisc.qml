import QtQuick
import "../Services"

// Disco lunar dibujado en Canvas con la fase real — la firma de Selene.
// phase: 0 nueva, 0.25 cuarto creciente, 0.5 llena, 0.75 menguante.
Canvas {
    id: root

    property real phase: Moon.phase
    property color discColor: Theme.surfaceBright
    property color litColor: Theme.text
    property color rimColor: Theme.alpha(Theme.accent, 0.35)

    implicitWidth: 22
    implicitHeight: 22
    antialiasing: true

    onPhaseChanged: requestPaint()
    onDiscColorChanged: requestPaint()
    onLitColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const cx = width / 2, cy = height / 2, r = Math.min(width, height) / 2 - 1;

        // Disco base (lado nocturno)
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.fillStyle = discColor;
        ctx.fill();

        // Región iluminada: semicírculo del lado iluminado + elipse
        // terminadora cuyo radio-x es r*cos(2π·phase).
        const t = phase * 2 * Math.PI;
        const k = Math.cos(t);           // 1 nueva · 0 cuarto · -1 llena
        const waxing = phase < 0.5;      // creciente: iluminado a la derecha
        const rx = Math.abs(k) * r;

        ctx.beginPath();
        // Borde externo del lado iluminado
        ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, !waxing);
        // Terminadora de vuelta al tope
        ctx.ellipse(cx, cy, rx, r, 0, Math.PI / 2, -Math.PI / 2, k > 0);
        ctx.closePath();
        ctx.fillStyle = litColor;
        ctx.fill();

        // Halo lunar fino
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.strokeStyle = rimColor;
        ctx.lineWidth = 1;
        ctx.stroke();
    }
}

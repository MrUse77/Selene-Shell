.pragma library

// Lógica pura de comandos externos (#25, D6).
//
// Sin imports de Qt ni de Quickshell: es ejecutable tal cual en qmltestrunner y
// no toca el sistema. Sólo decide; el QML decide cuándo spawnear.

// Precedencia de las claves de comando: el primer string no vacío gana y si
// ningún nivel es válido se devuelve el default. Misma semántica documentada
// para Theme.pick: un valor vacío, `undefined` o de tipo no-string cae al
// siguiente nivel, así un clic nunca rompe.
function resolve(envValue, settingValue, fallback) {
    const levels = [envValue, settingValue];
    for (let i = 0; i < levels.length; i++) {
        const value = levels[i];
        if (typeof value === "string" && value !== "") return value;
    }
    return fallback;
}

// argv de la sonda de ejecutabilidad (D3): `command -v` es la misma autoridad
// que después hará el exec (PATH + bit de ejecución), no una reimplementación
// del lookup del loader. El script es CONSTANTE y el nombre viaja como parámetro
// posicional ($1): NUNCA se interpola en la cadena del `-c`.
function probeArgv(name) {
    return ["sh", "-c", 'command -v -- "$1" >/dev/null 2>&1', "selene-command-probe", name];
}

// Tabla de decisión de los mensajes visibles. Las cadenas son byte a byte las
// que Services/Commands.qml emitía antes de #25.
function failureMessage(event, detail) {
    const data = detail || {};
    switch (event) {
    case "parse":
        return data.error;
    case "create":
        return "Unable to create the process";
    case "start":
        return "Unable to start " + data.program;
    default:
        return "";
    }
}

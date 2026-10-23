// Resolución pura del ícono propio de una aplicación.
//
// El launcher no puede pedirle el ícono al tema: QIcon::fromTheme busca primero
// el tema activo, y Quickshell no expone QIcon::setThemeName. La vía interna es
// resolver el archivo y entregarle a IconImage una ruta absoluta. `hicolor` es
// el tema donde cada aplicación instala el ícono que trae por defecto, y
// `pixmaps` es la ubicación legacy que el estándar deja como respaldo.
//
// Este módulo no importa nada (ni Quickshell ni singletons) para que
// qmltestrunner lo cubra sin levantar la shell.

// Prioridad de un archivo dentro del índice: estilo > origen > tamaño.
// - Estilo: scalable (svg) > raster (png) > symbolic (monocromo, solo último
//   recurso).
// - Origen: hicolor > pixmaps, el orden que fija el estándar freedesktop.
const STYLE_SCALABLE = 3;
const STYLE_RASTER = 2;
const STYLE_SYMBOLIC = 1;
const ORIGIN_HICOLOR = 2;
const ORIGIN_PIXMAPS = 1;
const STYLE_WEIGHT = 1e8;
const ORIGIN_WEIGHT = 1e6;
const HICOLOR_MARKER = "/icons/hicolor/";
const SIZE_PATTERN = /^(\d+)x(\d+)(?:@(\d+)x)?$/;
const EXTENSION_PATTERN = /\.(png|svg)$/i;

// Raíces de búsqueda en orden XDG: datos del usuario, XDG_DATA_DIRS y, si la
// variable falta o viene vacía, los defaults del estándar. Se descartan vacíos
// y duplicados para que `find` no recorra dos veces la misma raíz.
function dataDirs(envDataDirs, envDataHome, home) {
    const dirs = [];
    const add = (dir) => {
        if (typeof dir !== "string") return;
        const value = dir.trim();
        if (value === "" || dirs.indexOf(value) !== -1) return;
        dirs.push(value);
    };

    const homeDir = typeof home === "string" ? home.trim() : "";
    add(envDataHome || (homeDir !== "" ? homeDir + "/.local/share" : ""));

    const raw = typeof envDataDirs === "string" ? envDataDirs.trim() : "";
    if (raw === "") {
        add("/usr/local/share");
        add("/usr/share");
        return dirs;
    }
    const entries = raw.split(":");
    for (let i = 0; i < entries.length; i++) add(entries[i]);
    return dirs;
}

// Argumentos de un único `find` que indexa los íconos de app de todas las
// raíces: `<raíz>/icons/hicolor/<tamaño>/apps/*.(png|svg)` y
// `<raíz>/pixmaps/*.(png|svg)`. Se restringe a `apps/` a propósito: los íconos
// de mimetypes, devices o categories no son íconos de aplicación.
function findArgs(dirs) {
    const roots = Array.isArray(dirs) ? dirs : [];
    const args = [];
    for (let i = 0; i < roots.length; i++) args.push(roots[i] + "/icons/hicolor");
    for (let i = 0; i < roots.length; i++) args.push(roots[i] + "/pixmaps");
    return args.concat([
        "-type", "f",
        "(", "-path", "*/apps/*", "-o", "-path", "*/pixmaps/*", ")",
        "(", "-name", "*.png", "-o", "-name", "*.svg", ")",
        "-print"
    ]);
}

function _isAppIcon(path) {
    return path.indexOf("/apps/") !== -1 || path.indexOf("/pixmaps/") !== -1;
}

// Clave del índice: nombre del archivo sin extensión, que es exactamente el
// valor que un .desktop pone en `Icon=` o la clase de ventana de Hyprland.
function _key(path) {
    const base = path.slice(path.lastIndexOf("/") + 1);
    return base.replace(EXTENSION_PATTERN, "");
}

function _size(path) {
    const at = path.indexOf(HICOLOR_MARKER);
    if (at === -1) return 0;
    const segment = path.slice(at + HICOLOR_MARKER.length).split("/")[0];
    const match = SIZE_PATTERN.exec(segment);
    if (!match) return 0;
    const scale = match[3] ? Number(match[3]) : 1;
    return Number(match[1]) * scale;
}

function _rank(path) {
    const symbolic = path.indexOf("/symbolic/") !== -1;
    const scalable = !symbolic && EXTENSION_PATTERN.exec(path)?.[1].toLowerCase() === "svg";
    const style = symbolic ? STYLE_SYMBOLIC : (scalable ? STYLE_SCALABLE : STYLE_RASTER);
    const origin = path.indexOf(HICOLOR_MARKER) !== -1 ? ORIGIN_HICOLOR : ORIGIN_PIXMAPS;
    return style * STYLE_WEIGHT + origin * ORIGIN_WEIGHT + _size(path);
}

// Convierte la salida de `find` en dos mapas: `exact` con el nombre tal cual y
// `lower` con el nombre en minúsculas para el modo Ventanas, donde la clase de
// Hyprland no siempre respeta el caso del archivo (`Spotify` vs `spotify.png`).
// Ante empate de prioridad gana la ruta lexicográficamente menor, así el
// índice no depende del orden en que `find` recorra los directorios.
function parseIndex(stdout) {
    const exact = {};
    const exactRanks = {};
    const lower = {};
    const lowerRanks = {};
    const lines = String(stdout ?? "").split("\n");

    for (let i = 0; i < lines.length; i++) {
        const path = lines[i].trim();
        if (path === "" || !_isAppIcon(path)) continue;
        const key = _key(path);
        if (key === "") continue;
        const rank = _rank(path);

        if (!(key in exactRanks) || rank > exactRanks[key]
            || (rank === exactRanks[key] && path < exact[key])) {
            exactRanks[key] = rank;
            exact[key] = path;
        }

        const lowerKey = key.toLowerCase();
        if (!(lowerKey in lowerRanks) || rank > lowerRanks[lowerKey]
            || (rank === lowerRanks[lowerKey] && path < lower[lowerKey])) {
            lowerRanks[lowerKey] = rank;
            lower[lowerKey] = path;
        }
    }

    return { exact: exact, lower: lower };
}

// Búsqueda exacta y después sin distinguir mayúsculas; "" significa "no hay
// ícono propio" y el consumidor conserva el fallback del tema.
function resolve(icon, index) {
    if (typeof icon !== "string") return "";
    const name = icon.trim();
    if (name === "" || !index) return "";

    const exact = index.exact?.[name];
    if (typeof exact === "string") return exact;

    const lower = index.lower?.[name.toLowerCase()];
    return typeof lower === "string" ? lower : "";
}

function isAbsolutePath(icon) {
    return typeof icon === "string" && icon.trim().charAt(0) === "/";
}

function emptyIndex() {
    return { exact: {}, lower: {} };
}

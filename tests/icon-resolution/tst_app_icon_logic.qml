import QtQuick
import QtTest
import "../../Services/AppIconLogic.js" as AppIconLogic

// Tests deterministas de la resolución de íconos de aplicación.
// El módulo bajo prueba es JS puro (no importa singletons ni Quickshell), así
// que cubre el orden XDG, la prioridad dentro del índice y la búsqueda sin
// levantar la shell.
// Se ejecutan con: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/icon-resolution/tst_app_icon_logic.qml
TestCase {
    id: root
    name: "AppIconLogic"

    function test_data_dirs_put_data_home_first_and_keep_env_order() {
        compare(
            AppIconLogic.dataDirs("/usr/local/share:/usr/share", "/home/u/.local/share", "/home/u"),
            ["/home/u/.local/share", "/usr/local/share", "/usr/share"]
        );
    }

    function test_data_dirs_fall_back_to_the_xdg_defaults_when_unset() {
        compare(
            AppIconLogic.dataDirs("", "/home/u/.local/share", "/home/u"),
            ["/home/u/.local/share", "/usr/local/share", "/usr/share"]
        );
        compare(AppIconLogic.dataDirs(null, null, "/home/u"), ["/home/u/.local/share", "/usr/local/share", "/usr/share"]);
    }

    function test_data_dirs_drop_empty_and_duplicated_entries() {
        compare(
            AppIconLogic.dataDirs("/usr/share::/usr/share:/opt/share:", "/home/u/.local/share", "/home/u"),
            ["/home/u/.local/share", "/usr/share", "/opt/share"]
        );
    }

    function test_find_args_search_hicolor_apps_and_pixmaps_only() {
        const args = AppIconLogic.findArgs(["/a", "/b"]);
        compare(args.slice(0, 4), ["/a/icons/hicolor", "/b/icons/hicolor", "/a/pixmaps", "/b/pixmaps"]);
        verify(args.indexOf("-path") !== -1);
        verify(args.indexOf("*/apps/*") !== -1);
        verify(args.indexOf("*.svg") !== -1);
        verify(args.indexOf("*.png") !== -1);
        verify(args.indexOf("*.xpm") === -1);
    }

    function test_index_prefers_the_scalable_svg_over_rasters() {
        const index = AppIconLogic.parseIndex([
            "/usr/share/icons/hicolor/48x48/apps/firefox.png",
            "/usr/share/icons/hicolor/scalable/apps/firefox.svg",
            "/usr/share/icons/hicolor/384x384/apps/firefox.png"
        ].join("\n"));
        compare(index.exact["firefox"], "/usr/share/icons/hicolor/scalable/apps/firefox.svg");
    }

    function test_index_prefers_the_largest_raster_and_counts_2x() {
        const index = AppIconLogic.parseIndex([
            "/usr/share/icons/hicolor/48x48/apps/discord.png",
            "/usr/share/icons/hicolor/256x256/apps/discord.png",
            "/usr/share/icons/hicolor/64x64@2x/apps/discord.png"
        ].join("\n"));
        compare(index.exact["discord"], "/usr/share/icons/hicolor/256x256/apps/discord.png");
    }

    function test_index_ranks_hicolor_above_pixmaps() {
        const index = AppIconLogic.parseIndex([
            "/usr/share/pixmaps/steam.png",
            "/usr/share/icons/hicolor/32x32/apps/steam.png"
        ].join("\n"));
        compare(index.exact["steam"], "/usr/share/icons/hicolor/32x32/apps/steam.png");
    }

    function test_index_ranks_symbolic_below_colored_icons() {
        const index = AppIconLogic.parseIndex([
            "/usr/share/icons/hicolor/symbolic/apps/flatseal.svg",
            "/usr/share/icons/hicolor/48x48/apps/flatseal.png"
        ].join("\n"));
        compare(index.exact["flatseal"], "/usr/share/icons/hicolor/48x48/apps/flatseal.png");
    }

    function test_index_keys_are_file_names_without_extension() {
        const index = AppIconLogic.parseIndex([
            "/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps/com.github.tchx84.Flatseal.png"
        ].join("\n"));
        compare(index.exact["com.github.tchx84.Flatseal"], "/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps/com.github.tchx84.Flatseal.png");
        compare(index.exact["com.github.tchx84.Flatseal.png"], undefined);
    }

    function test_index_ignores_blank_lines_and_files_outside_apps() {
        const index = AppIconLogic.parseIndex([
            "",
            "   ",
            "/usr/share/icons/hicolor/16x16/mimetypes/text-plain.png"
        ].join("\n"));
        compare(Object.keys(index.exact).length, 0);
    }

    function test_resolve_matches_case_insensitively_for_window_classes() {
        const index = AppIconLogic.parseIndex([
            "/usr/share/icons/hicolor/32x32/apps/spotify.png"
        ].join("\n"));
        compare(AppIconLogic.resolve("spotify", index), "/usr/share/icons/hicolor/32x32/apps/spotify.png");
        compare(AppIconLogic.resolve("Spotify", index), "/usr/share/icons/hicolor/32x32/apps/spotify.png");
    }

    function test_resolve_prefers_an_exact_match_over_a_case_variant() {
        const index = AppIconLogic.parseIndex([
            "/usr/share/icons/hicolor/48x48/apps/Code.png",
            "/usr/share/icons/hicolor/32x32/apps/code.png"
        ].join("\n"));
        compare(AppIconLogic.resolve("code", index), "/usr/share/icons/hicolor/32x32/apps/code.png");
        compare(AppIconLogic.resolve("Code", index), "/usr/share/icons/hicolor/48x48/apps/Code.png");
    }

    function test_resolve_returns_empty_for_missing_or_blank_names() {
        const index = AppIconLogic.parseIndex("/usr/share/icons/hicolor/48x48/apps/firefox.png");
        compare(AppIconLogic.resolve("code", index), "");
        compare(AppIconLogic.resolve("", index), "");
        compare(AppIconLogic.resolve(undefined, index), "");
    }

    function test_absolute_paths_are_detected_and_used_as_is() {
        compare(AppIconLogic.isAbsolutePath("/home/u/icon.png"), true);
        compare(AppIconLogic.isAbsolutePath("firefox"), false);
        compare(AppIconLogic.isAbsolutePath(""), false);
        compare(AppIconLogic.isAbsolutePath(undefined), false);
    }
}

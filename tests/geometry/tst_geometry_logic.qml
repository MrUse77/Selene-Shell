import QtQuick
import QtTest
import "../../Services/GeometryLogic.js" as GeometryLogic

// Tests deterministas de la resolución de la geometría de la barra.
// El módulo bajo prueba es puro (no importa singletons ni Quickshell), así que
// cubre parseo y validación sin levantar la shell.
// Se ejecutan con: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/geometry/tst_geometry_logic.qml
TestCase {
    id: root
    name: "GeometryLogic"

    // Las constantes de rango pueden quedar expuestas como valor o como
    // función según lo que soporte la versión de Qt; el test las lee igual en
    // cualquiera de las dos formas.
    function rangeConstant(name) {
        const value = GeometryLogic[name];
        return typeof value === "function" ? value() : value;
    }

    function test_range_constants_are_reachable_from_the_test() {
        compare(root.rangeConstant("MIN_BAR_HEIGHT"), 34);
        compare(root.rangeConstant("MAX_BAR_HEIGHT"), 96);
        compare(root.rangeConstant("MIN_MARGIN"), 0);
        compare(root.rangeConstant("MAX_MARGIN"), 200);
    }

    function test_integer_values_are_parsed_from_strings_and_numbers() {
        compare(GeometryLogic.resolve("44", 7, 34, 96), 44);
        compare(GeometryLogic.resolve(44, 7, 34, 96), 44);
        compare(GeometryLogic.resolve(" 44 ", 7, 34, 96), 44);
        compare(GeometryLogic.resolve("0", 7, 0, 200), 0);
    }

    function test_empty_and_missing_values_fall_back() {
        compare(GeometryLogic.resolve("", 7, 34, 96), 7);
        compare(GeometryLogic.resolve("   ", 7, 34, 96), 7);
        compare(GeometryLogic.resolve(null, 7, 34, 96), 7);
        compare(GeometryLogic.resolve(undefined, 7, 34, 96), 7);
    }

    function test_malformed_values_fall_back() {
        compare(GeometryLogic.resolve("abc", 7, 34, 96), 7);
        compare(GeometryLogic.resolve("44.5", 7, 34, 96), 7);
        compare(GeometryLogic.resolve("4e2px", 7, 34, 96), 7);
        compare(GeometryLogic.resolve(Infinity, 7, 34, 96), 7);
        compare(GeometryLogic.resolve(NaN, 7, 34, 96), 7);
        compare(GeometryLogic.resolve(true, 7, 34, 96), 7);
        compare(GeometryLogic.resolve({}, 7, 34, 96), 7);
    }

    // El fallback es el valor de confianza: se devuelve tal cual, sin acotar.
    function test_fallback_is_returned_verbatim() {
        compare(GeometryLogic.resolve("", 999, 34, 96), 999);
        compare(GeometryLogic.resolve("abc", -1, 34, 96), -1);
    }

    function test_integers_are_clamped_into_the_range() {
        compare(GeometryLogic.resolve("10", 7, 34, 96), 34);
        compare(GeometryLogic.resolve("200", 7, 34, 96), 96);
        compare(GeometryLogic.resolve("-5", 7, 34, 96), 34);
        compare(GeometryLogic.resolve(0, 7, 0, 200), 0);
        compare(GeometryLogic.resolve(1e9, 7, 34, 96), 96);
    }
}

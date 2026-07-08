pragma Singleton
import QtQuick

// Central design tokens for the whole application
QtObject {
    // Palette - dark industrial
    readonly property color background:     "#10141b"
    readonly property color surface:        "#1a212c"
    readonly property color surfaceLight:   "#222b39"
    readonly property color surfaceHover:   "#2a3546"
    readonly property color border:         "#303c4f"
    readonly property color accent:         "#4dabf7"
    readonly property color accentDim:      "#2b5d8a"
    readonly property color success:        "#51cf66"
    readonly property color warning:        "#fcc419"
    readonly property color error:          "#ff6b6b"
    readonly property color textPrimary:    "#e9eef5"
    readonly property color textSecondary:  "#8b98ab"
    readonly property color textDisabled:   "#5a6675"

    // Metrics
    readonly property int radius: 8
    readonly property int spacing: 10
    readonly property int headerHeight: 56

    // Fonts
    readonly property string monoFont: "Consolas"
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeNormal: 13
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeTitle: 20

    // Formatting helpers shared across views
    function toHex(value) {
        return "0x" + value.toString(16).padStart(4, "0").toUpperCase()
    }

    function toBinary(value) {
        var bits = value.toString(2).padStart(16, "0")
        // Group by nibbles for readability: 0000 0000 0000 0000
        return bits.replace(/(.{4})(?=.)/g, "$1 ")
    }

    function levelColor(line) {
        if (line.indexOf("[CRITICAL]") !== -1 || line.indexOf("[FATAL]") !== -1)
            return error
        if (line.indexOf("[WARNING]") !== -1)
            return warning
        if (line.indexOf("[INFO]") !== -1)
            return accent
        if (line.indexOf("[DEBUG]") !== -1)
            return textSecondary
        return textPrimary
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root

    // Nerd Font icon glyphs (Theme.cp, "\uf…") aren't in SF Pro; fontconfig falls back
    // to FiraCode Nerd Font, the only installed font that has them.
    readonly property string fontFamily: "SF Pro Display"
    // SF Pro digits are proportional; use on changing numbers (clock, percentages).
    readonly property var tabularFigures: ({
            "tnum": 1
        })

    // ---- Kitty palette snapshot ----
    // Copied from ~/.config/kitty/{colors,kitty}.conf; regenerate with
    // `python3 scripts/sync-kitty-theme.py` after changing the Kitty colours.
    // BEGIN kitty palette
    readonly property color kittyBackground: "#0e1017"
    readonly property color kittyForeground: "#787c99"
    readonly property color color0: "#24283b"
    readonly property color color1: "#f7768e"
    readonly property color color2: "#41a6b5"
    readonly property color color3: "#e0af68"
    readonly property color color4: "#8698df"
    readonly property color color5: "#bb9af7"
    readonly property color color6: "#8698df"
    readonly property color color8: "#444b6a"
    readonly property color color15: "#d5d6db"
    readonly property real kittyOpacity: 0.85
    // END kitty palette

    // ---- Roles (same mapping as the GTK theme in gtk-theme-tokyo-night/build.py) ----
    readonly property color background: kittyBackground     // pills, island, menus
    readonly property color raised: color0                  // tiles, cards, tracks, dividers
    readonly property color raisedHover: mix(color0, color8, 0.5)   // hovered/selected tiles and rows
    readonly property color raisedActive: mix(color0, color4, 0.25) // active (connected) tiles
    readonly property color border: color8
    readonly property color borderSubtle: alpha(color8, 0.6)
    readonly property color text: color15
    readonly property color foreground: color15             // icons and status text
    readonly property color muted: kittyForeground          // secondary text
    readonly property color highlight: color4               // accent
    readonly property color purple: color5
    readonly property color cyan: color6
    readonly property color success: color2
    readonly property color warning: color3
    readonly property color danger: color1
    readonly property color surface: alpha(background, 0.97)     // island and menu pill
    readonly property color pill: alpha(background, 0.94)        // other bar pills
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
    function mix(a, b, p) {
        return Qt.rgba(a.r + (b.r - a.r) * p, a.g + (b.g - a.g) * p, a.b + (b.b - a.b) * p, a.a + (b.a - a.a) * p)
    }
    // [fill, border, text] for a tinted badge.
    function badge(c) {
        return [mix(background, c, 0.2), c, mix(c, text, 0.5)]
    }
    readonly property int islandBaseWidth: 300
    readonly property int islandHeliumWidth: islandBaseWidth * 2
    readonly property int windowTitleMaxWidth: 400
    readonly property real workspacePreviewScale: 0.4
    readonly property real workspaceIconScale: 1.5
    readonly property int islandFadeDuration: 120
    readonly property int barHeight: 42
    readonly property int topMargin: 8
    // Compact bar, while a window spans the output width (maximized/fullscreen):
    // a flush full-width strip with modules scaled down.
    readonly property real compactScale: 0.9
    readonly property int compactBarHeight: 40
    readonly property int compactPadding: 10
    readonly property color compactBackground: alpha(background, kittyOpacity)
    readonly property int compactDuration: 260
    // Top of a scaled module when centred in the compact strip.
    readonly property real compactTop: (compactBarHeight - barHeight * compactScale) / 2
    readonly property int closedRadius: 12
    readonly property int openRadius: 18
    readonly property int fadeDuration: 180
    readonly property int morphDuration: 400
    function cp(n) {
        return String.fromCodePoint(n)
    }
}

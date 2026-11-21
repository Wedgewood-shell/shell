pragma Singleton
import Quickshell

Singleton {
    readonly property string backlightPath: "/sys/class/backlight/intel_backlight"
    readonly property string acOnlinePath: "/sys/class/power_supply/ADP1/online"
    readonly property string batteryPath: "/sys/class/power_supply/BAT0"
    readonly property string cpuTemperatureGlob: "/sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input"
    // Smart fullscreen: when one of these apps (niri app_id) spans the output width,
    // the bar stops reserving space so the window grows underneath it, and the bar
    // blurs what is behind it instead of drawing a background.
    readonly property var smartFullscreenApps: ["kitty"]
}

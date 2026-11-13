pragma Singleton
import Quickshell

Singleton {
    readonly property string backlightPath: "/sys/class/backlight/intel_backlight"
    readonly property string acOnlinePath: "/sys/class/power_supply/ADP1/online"
    readonly property string batteryPath: "/sys/class/power_supply/BAT0"
    // Mirror of niri's touchpad `natural-scroll`; niri inverts swipe deltas with it.
    readonly property bool touchpadNaturalScroll: true
    readonly property string cpuTemperatureGlob: "/sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input"
}

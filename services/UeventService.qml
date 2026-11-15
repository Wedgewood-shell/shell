pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One long-running `udevadm monitor` replaces sysfs polling. The kernel emits a
// change uevent whenever the backlight level or a power supply (AC adapter,
// battery status) changes, so idle costs no wakeups.
Singleton {
    id: root
    signal backlight
    signal powerSupply

    Process {
        id: monitor
        running: true
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight", "--subsystem-match=power_supply"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.endsWith("(backlight)"))
                    root.backlight()
                else if (line.endsWith("(power_supply)"))
                    root.powerSupply()
            }
        }
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 5000
        onTriggered: {
            monitor.running = true
            // Changes may have been missed while the monitor was down.
            root.backlight()
            root.powerSupply()
        }
    }
}

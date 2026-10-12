import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var shell: null
    property bool sharingActive: false
    property string serviceState: "unknown"
    property bool needsSetup: false
    property string omarchyPath: Quickshell.env("OMARCHY_PATH")

    readonly property string setupScript:
        Qt.resolvedUrl("scripts/plugin-setup.sh").toString().replace("file://", "")

    readonly property string launchTerminal:
        (omarchyPath !== "" ? omarchyPath : "/usr/share/omarchy") + "/bin/omarchy-launch-terminal"

    function refreshStatus() {
        statusProcess.running = true
    }

    function checkSetup() {
        setupCheck.running = true
    }

    function runSetup() {
        if (setupScript === "")
            return false
        Quickshell.execDetached([launchTerminal, setupScript])
        return true
    }

    function start() {
        startProcess.running = true
        return "ok"
    }

    function stop() {
        stopProcess.running = true
        return "ok"
    }

    function status(): string {
        return serviceState
    }

    Process {
        id: setupCheck
        command: ["bash", "-lc", "command -v gnirehtet >/dev/null 2>&1 && [ -f \"$HOME/.config/systemd/user/usb-internet-share.service\" ] && echo ok || echo missing"]

        stdout: StdioCollector {
            onStreamFinished: root.needsSetup = (text.trim() !== "ok")
        }
    }

    Process {
        id: statusProcess
        command: ["systemctl", "--user", "is-active", "usb-internet-share.service"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.serviceState = text.trim()
                root.sharingActive = root.serviceState === "active"
            }
        }

        onExited: function(exitCode) {
            if (exitCode !== 0 && root.serviceState === "unknown") {
                root.sharingActive = false
            }
        }
    }

    Process {
        id: startProcess
        command: ["systemctl", "--user", "start", "usb-internet-share.service"]

        onExited: function(exitCode) {
            root.refreshStatus()
        }
    }

    Process {
        id: stopProcess
        command: ["systemctl", "--user", "stop", "usb-internet-share.service"]

        onExited: function(exitCode) {
            root.refreshStatus()
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.refreshStatus()
            root.checkSetup()
        }
    }

    IpcHandler {
        target: "usb-internet-share"

        function status(): string {
            return root.status()
        }

        function needsSetup(): bool {
            return root.needsSetup
        }

        function setup(): string {
            return root.runSetup() ? "ok" : "unavailable"
        }

        function start(): string {
            return root.start()
        }

        function stop(): string {
            return root.stop()
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var shell: null
    property bool sharingActive: false
    property string serviceState: "unknown"

    function refreshStatus() {
        statusProcess.running = true
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
        onTriggered: root.refreshStatus()
    }

    IpcHandler {
        target: "usb-internet-share"

        function status(): string {
            return root.status()
        }

        function start(): string {
            return root.start()
        }

        function stop(): string {
            return root.stop()
        }
    }
}

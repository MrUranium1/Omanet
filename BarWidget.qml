import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "mehir.usb-internet-share"

    readonly property var shareService:
        bar?.shell?.serviceFor("mehir.usb-internet-share")

    readonly property bool sharing:
        shareService ? shareService.sharingActive : false

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "USB"
        active: root.sharing
        tooltipText: root.sharing
            ? "USB Internet Share: Active"
            : "USB Internet Share: Inactive"

        onPressed: function(mouseButton) {
            if (!root.shareService)
                return

            if (mouseButton === Qt.LeftButton) {
                if (root.sharing)
                    root.shareService.stop()
                else
                    root.shareService.start()
            } else if (mouseButton === Qt.RightButton) {
                root.shareService.refreshStatus()
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (root.shareService)
                root.shareService.refreshStatus()
        }
    }
}

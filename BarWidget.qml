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

    readonly property string serviceState:
        shareService ? String(shareService.serviceState || "unknown") : "unknown"

    readonly property bool busy:
        serviceState === "activating" || serviceState === "deactivating"

    readonly property color fg: bar ? bar.foreground : Color.foreground
    readonly property color accent: Color.accent

    property bool popupOpen: false

    function close() {
        popupOpen = false
    }

    function toggle() {
        if (!shareService || busy)
            return
        if (sharing)
            shareService.stop()
        else
            shareService.start()
    }

    function stateLabel() {
        if (sharing)
            return "Sharing"
        if (serviceState === "activating")
            return "Starting"
        if (serviceState === "deactivating")
            return "Stopping"
        if (serviceState === "failed")
            return "Failed"
        if (serviceState === "inactive")
            return "Stopped"
        return "Unknown"
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onPopupOpenChanged: {
        if (popupOpen && shareService)
            shareService.refreshStatus()
    }

    component StatusRow: Item {
        id: row
        property color foreground: Color.foreground
        property color dot: foreground
        property string label: ""
        property string value: ""

        width: parent ? parent.width : 0
        implicitHeight: Math.max(rowLabel.implicitHeight, rowValue.implicitHeight, Style.space(6))
        height: implicitHeight

        Rectangle {
            id: dotRect
            width: Style.space(6)
            height: width
            radius: width / 2
            color: row.dot
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: rowLabel
            textFormat: Text.PlainText
            anchors.left: dotRect.right
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: Qt.darker(row.foreground, 1.35)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }

        Text {
            id: rowValue
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.value
            color: row.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
        }
    }

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "\uf287"
        active: root.sharing
        tooltipText: "USB Internet Share — " + root.stateLabel()

        onPressed: function(mouseButton) {
            if (!root.shareService)
                return

            if (mouseButton === Qt.LeftButton) {
                root.popupOpen = !root.popupOpen
            } else if (mouseButton === Qt.RightButton) {
                root.toggle()
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

    PopupCard {
        id: popup
        anchorItem: root
        bar: root.bar
        owner: root
        open: root.popupOpen
        contentWidth: popup.fittedContentWidth(Style.space(300))
        contentHeight: popup.fittedContentHeight(column.implicitHeight)

        Column {
            id: column
            anchors.fill: parent
            spacing: Style.space(12)

            PanelHero {
                width: parent.width
                foreground: root.fg
                title: "USB Internet Share"
                meta: "GNirehtet · reverse tethering"
                detail: root.sharing ? "ON" : "OFF"

                iconComponent: Component {
                    Text {
                        textFormat: Text.PlainText
                        text: "\uf287"
                        color: root.sharing ? root.accent : root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.displayLarge

                        Behavior on color {
                            ColorAnimation { duration: 160 }
                        }
                    }
                }

                trailingControl: Component {
                    PanelActionButton {
                        iconText: "\uf021"
                        tooltipText: "Refresh status"
                        foreground: root.fg
                        onClicked: {
                            if (root.shareService)
                                root.shareService.refreshStatus()
                        }
                    }
                }
            }

            Button {
                width: parent.width
                leftAlign: true
                bordered: true
                selected: root.sharing
                foreground: root.fg
                iconText: root.sharing ? "\uf04d" : "\uf04b"
                text: root.busy
                    ? (root.sharing ? "Stopping…" : "Starting…")
                    : (root.sharing ? "Stop sharing" : "Start sharing")
                enabled: !root.busy
                opacity: enabled ? 1.0 : 0.55
                tooltipText: root.sharing
                    ? "Stop sharing internet to the connected device"
                    : "Start sharing internet to the connected device"
                onClicked: root.toggle()
            }

            PanelSeparator {
                foreground: root.fg
            }

            Column {
                width: parent.width
                spacing: Style.space(8)

                PanelSectionHeader {
                    text: "Status"
                    foreground: root.fg
                }

                StatusRow {
                    foreground: root.fg
                    label: "Service"
                    value: root.stateLabel()
                    dot: root.sharing
                        ? root.accent
                        : (root.serviceState === "failed" ? Color.urgent : Qt.darker(root.fg, 1.6))
                }

                StatusRow {
                    foreground: root.fg
                    label: "Mode"
                    value: "Reverse tethering"
                }

                StatusRow {
                    foreground: root.fg
                    label: "Link"
                    value: "Android via USB"
                }
            }
        }
    }
}

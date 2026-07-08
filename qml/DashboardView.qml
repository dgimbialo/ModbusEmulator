import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// Traffic statistics + a real-time trend chart of any register
Item {
    id: root

    property real uptimeSeconds: 0

    function formatUptime(seconds) {
        var s = Math.floor(seconds)
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        function pad(n) { return n.toString().padStart(2, "0") }
        return pad(h) + ":" + pad(m) + ":" + pad(sec)
    }

    // Uptime counter
    property double startedAt: 0

    Connections {
        target: modbusServer
        function onRunningChanged() {
            if (modbusServer.running) {
                root.startedAt = Date.now()
                root.uptimeSeconds = 0
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: modbusServer.running
        onTriggered: root.uptimeSeconds = (Date.now() - root.startedAt) / 1000
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        // Metric tiles
        GridLayout {
            Layout.fillWidth: true
            columns: width > 900 ? 5 : 3
            columnSpacing: Theme.spacing
            rowSpacing: Theme.spacing

            StatTile {
                Layout.fillWidth: true
                caption: qsTr("Read requests")
                value: modbusServer.readRequests
                glyph: "⇣"
                accentColor: Theme.accent
            }

            StatTile {
                Layout.fillWidth: true
                caption: qsTr("Write requests")
                value: modbusServer.writeRequests
                glyph: "⇡"
                accentColor: Theme.success
            }

            StatTile {
                Layout.fillWidth: true
                caption: qsTr("Errors")
                value: modbusServer.errorCount
                glyph: "⚠"
                accentColor: modbusServer.errorCount > 0 ? Theme.error : Theme.textDisabled
            }

            StatTile {
                Layout.fillWidth: true
                caption: qsTr("Uptime")
                value: modbusServer.running ? root.formatUptime(root.uptimeSeconds) : "—"
                glyph: "◷"
                accentColor: Theme.warning
            }

            StatTile {
                Layout.fillWidth: true
                caption: qsTr("Status")
                value: modbusServer.running ? qsTr("Online") : qsTr("Offline")
                glyph: "●"
                accentColor: modbusServer.running ? Theme.success : Theme.error
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: qsTr("Reset statistics")
                flat: true
                onClicked: modbusServer.resetStatistics()
            }

            Button {
                text: qsTr("Reset all registers")
                flat: true
                Material.foreground: Theme.error
                onClicked: modbusDataStore.resetAll()
            }

            Item { Layout.fillWidth: true }
        }

        // Live trend chart
        Frame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Material.background: Theme.surface

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        text: qsTr("Register trend")
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    ComboBox {
                        id: chartTypeCombo
                        model: [qsTr("Input register"), qsTr("Holding register")]
                        Layout.preferredWidth: 170
                        onActivated: chart.clear()
                    }

                    SpinBox {
                        id: chartAddressSpin
                        from: 0
                        to: 29999
                        editable: true
                        onValueModified: chart.clear()
                    }

                    Switch {
                        id: samplingSwitch
                        text: qsTr("Sample")
                        checked: true
                    }
                }

                ValueChart {
                    id: chart
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: samplingSwitch.checked && root.visible
        onTriggered: {
            var value = chartTypeCombo.currentIndex === 0
                    ? modbusDataStore.getInputRegister(chartAddressSpin.value)
                    : modbusDataStore.getHoldingRegister(chartAddressSpin.value)
            chart.push(value)
        }
    }
}

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// Right-side drawer with all connection settings (RTU / TCP).
// The C++ ModbusServer properties are the single source of truth; they are
// stored in the project file and applied on project load.
Drawer {
    id: root

    edge: Qt.RightEdge
    width: 360
    modal: true
    Material.background: Theme.surface

    // Pull current backend values into the controls
    function syncFromServer() {
        modeTabs.currentIndex = modbusServer.connectionType

        var idx = portCombo.find(modbusServer.portName)
        if (idx >= 0)
            portCombo.currentIndex = idx

        idx = baudCombo.model.indexOf(modbusServer.baudRate)
        baudCombo.currentIndex = idx >= 0 ? idx : baudCombo.model.length - 1

        idx = dataBitsCombo.model.indexOf(modbusServer.dataBits)
        dataBitsCombo.currentIndex = idx >= 0 ? idx : dataBitsCombo.model.length - 1

        idx = parityCombo.indexOfValue(modbusServer.parity)
        parityCombo.currentIndex = idx >= 0 ? idx : 0

        idx = stopBitsCombo.model.indexOf(modbusServer.stopBits)
        stopBitsCombo.currentIndex = idx >= 0 ? idx : 0

        tcpPortSpin.value = modbusServer.tcpPort
        unitIdSpin.value = modbusServer.serverAddress
    }

    Component.onCompleted: syncFromServer()

    Connections {
        target: modbusServer
        function onSettingsChanged() { root.syncFromServer() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: qsTr("Connection settings")
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
                color: Theme.textPrimary
                Layout.fillWidth: true
            }

            ToolButton {
                text: "✕"
                onClicked: root.close()
            }
        }

        Label {
            visible: modbusServer.running
            text: qsTr("Stop the server to change settings")
            color: Theme.warning
            font.pixelSize: Theme.fontSizeSmall
        }

        // Everything below is locked while the server runs
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14
            enabled: !modbusServer.running

            // Mode selector
            TabBar {
                id: modeTabs
                Layout.fillWidth: true
                onCurrentIndexChanged: modbusServer.connectionType = currentIndex

                TabButton { text: qsTr("Serial RTU") }
                TabButton { text: qsTr("Modbus TCP") }
            }

            StackLayout {
                Layout.fillWidth: true
                currentIndex: modeTabs.currentIndex

                // --- RTU settings ---
                GridLayout {
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 10

                    Label { text: qsTr("Serial port"); color: Theme.textSecondary }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        ComboBox {
                            id: portCombo
                            Layout.fillWidth: true
                            model: modbusServer.availablePorts
                            onActivated: modbusServer.portName = currentText
                        }

                        ToolButton {
                            text: "⟳"
                            font.pixelSize: 16
                            onClicked: modbusServer.refreshPorts()
                            ToolTip.visible: hovered
                            ToolTip.delay: 500
                            ToolTip.text: qsTr("Rescan serial ports")
                        }
                    }

                    Label { text: qsTr("Baud rate"); color: Theme.textSecondary }
                    ComboBox {
                        id: baudCombo
                        Layout.fillWidth: true
                        model: [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200]
                        onActivated: modbusServer.baudRate = currentValue
                    }

                    Label { text: qsTr("Data bits"); color: Theme.textSecondary }
                    ComboBox {
                        id: dataBitsCombo
                        Layout.fillWidth: true
                        model: [5, 6, 7, 8]
                        onActivated: modbusServer.dataBits = currentValue
                    }

                    Label { text: qsTr("Parity"); color: Theme.textSecondary }
                    ComboBox {
                        id: parityCombo
                        Layout.fillWidth: true
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { text: qsTr("None"), value: 0 },
                            { text: qsTr("Even"), value: 2 },
                            { text: qsTr("Odd"),  value: 3 }
                        ]
                        onActivated: modbusServer.parity = currentValue
                    }

                    Label { text: qsTr("Stop bits"); color: Theme.textSecondary }
                    ComboBox {
                        id: stopBitsCombo
                        Layout.fillWidth: true
                        model: [1, 2]
                        onActivated: modbusServer.stopBits = currentValue
                    }
                }

                // --- TCP settings ---
                GridLayout {
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 10

                    Label { text: qsTr("Listen address"); color: Theme.textSecondary }
                    Label {
                        text: "0.0.0.0 " + qsTr("(all interfaces)")
                        color: Theme.textPrimary
                        font.family: Theme.monoFont
                    }

                    Label { text: qsTr("TCP port"); color: Theme.textSecondary }
                    SpinBox {
                        id: tcpPortSpin
                        Layout.fillWidth: true
                        from: 1
                        to: 65535
                        editable: true
                        onValueModified: modbusServer.tcpPort = value
                    }
                }
            }

            // Common: unit id
            GridLayout {
                columns: 2
                columnSpacing: 12
                rowSpacing: 10
                Layout.fillWidth: true

                Label { text: qsTr("Unit ID (slave)"); color: Theme.textSecondary }
                SpinBox {
                    id: unitIdSpin
                    from: 1
                    to: 247
                    editable: true
                    Layout.fillWidth: true
                    onValueModified: modbusServer.serverAddress = value
                }
            }

            Item { Layout.fillHeight: true }
        }

        // Footer: summary + start/stop
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        Label {
            Layout.fillWidth: true
            text: modbusServer.statusText
            color: modbusServer.running ? Theme.success
                 : modbusServer.lastError !== "" ? Theme.error : Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        Button {
            Layout.fillWidth: true
            text: modbusServer.running ? qsTr("Stop server") : qsTr("Start server")
            highlighted: !modbusServer.running
            Material.background: modbusServer.running ? Theme.error : undefined
            onClicked: {
                if (modbusServer.running)
                    modbusServer.stop()
                else
                    modbusServer.start()
            }
        }
    }
}

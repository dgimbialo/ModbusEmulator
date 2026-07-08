import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// Editor for register metadata: a display name for the register itself
// and an individual name for each of its 16 bits (shown in bit tooltips).
Dialog {
    id: root

    property int address: 0
    property string typeName: ""

    signal submitted(int address, string name, var bits)

    title: qsTr("Register %1 · %2").arg(address).arg(typeName)
    modal: true
    anchors.centerIn: parent
    width: 470
    height: Math.min(620, parent ? parent.height - 40 : 620)
    standardButtons: Dialog.Ok | Dialog.Cancel
    Material.background: Theme.surfaceLight

    // Fill the fields with the current metadata and show the dialog
    function openFor(addr, currentName, currentBits) {
        address = addr
        nameField.text = currentName || ""
        for (var i = 0; i < 16; ++i) {
            var row = bitRepeater.itemAt(i)
            row.value = (currentBits && currentBits[String(row.bit)]) ? currentBits[String(row.bit)] : ""
        }
        open()
        nameField.forceActiveFocus()
    }

    onAccepted: {
        var bits = {}
        for (var i = 0; i < 16; ++i) {
            var row = bitRepeater.itemAt(i)
            var v = row.value.trim()
            if (v !== "")
                bits[String(row.bit)] = v
        }
        submitted(address, nameField.text.trim(), bits)
    }

    contentItem: ColumnLayout {
        spacing: 8

        Label {
            text: qsTr("Register name")
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }

        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: qsTr("e.g. Motor speed setpoint")
            selectByMouse: true
        }

        Label {
            Layout.topMargin: 6
            text: qsTr("Bit names (shown when hovering a bit)")
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }

        ScrollView {
            id: bitScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: bitScroll.availableWidth
                spacing: 4

                Repeater {
                    id: bitRepeater
                    model: 16

                    RowLayout {
                        id: bitRow
                        required property int index
                        readonly property int bit: 15 - index
                        property alias value: bitField.text

                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 24
                            radius: 4
                            color: Theme.surface
                            border.color: Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: bitRow.bit
                                color: Theme.accent
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        TextField {
                            id: bitField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Bit %1 name").arg(bitRow.bit)
                            selectByMouse: true
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}

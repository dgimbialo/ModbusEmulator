import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Single-line register row: address badge, user-defined name, editable
// decimal value, hex representation, an inline 16-bit editor (with named
// bits shown in tooltips) and an Edit button for the metadata dialog.
Rectangle {
    id: root

    property int address: 0
    property int registerType: 4      // 3 = Input, 4 = Holding
    property int dataRevision: 0      // bumped by the view on data changes
    property int metaRevision: 0      // bumped by the view on name changes
    property var nameProvider: null   // RegisterView: getRegisterName()/getBitName()

    // Column widths (controlled by the view header splitters)
    property int addressColW: 76
    property int nameColW: 130
    property int valueColW: 84
    property int hexColW: 76

    signal editRequested(int address)

    // Re-evaluated whenever dataRevision changes (dependency injection trick)
    readonly property int regValue: {
        dataRevision
        return registerType === 3 ? modbusDataStore.getInputRegister(address)
                                  : modbusDataStore.getHoldingRegister(address)
    }

    readonly property string regName: {
        metaRevision
        return nameProvider ? nameProvider.getRegisterName(address) : ""
    }

    height: 34
    radius: 5
    color: rowHover.hovered ? Theme.surfaceHover : Theme.surface
    border.color: Theme.border
    border.width: 1

    HoverHandler { id: rowHover }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 0

        // Address badge
        Rectangle {
            Layout.preferredWidth: root.addressColW
            Layout.preferredHeight: 22
            radius: 11
            color: Theme.surfaceLight
            border.color: Theme.border

            Text {
                anchors.centerIn: parent
                text: root.address
                color: Theme.accent
                font.family: Theme.monoFont
                font.pixelSize: 14
                font.bold: true
            }

            HoverHandler { id: badgeHover }
            ToolTip.visible: badgeHover.hovered
            ToolTip.delay: 400
            ToolTip.text: qsTr("Entity address: %1%2")
                          .arg(root.registerType === 3 ? "3" : "4")
                          .arg((root.address + 1).toString().padStart(4, "0"))
        }

        Item { Layout.preferredWidth: 10 }

        // User-defined register name
        Text {
            Layout.preferredWidth: root.nameColW
            text: root.regName
            color: Theme.textPrimary
            font.pixelSize: 14
            elide: Text.ElideRight

            HoverHandler { id: nameHover; enabled: root.regName !== "" }
            ToolTip.visible: nameHover.hovered && truncated
            ToolTip.delay: 400
            ToolTip.text: root.regName
        }

        Item { Layout.preferredWidth: 10 }

        // Decimal value editor
        TextField {
            id: valueField
            Layout.preferredWidth: root.valueColW
            Layout.preferredHeight: 26
            topPadding: 1
            bottomPadding: 1
            horizontalAlignment: TextInput.AlignHCenter
            font.family: Theme.monoFont
            font.pixelSize: 14
            color: Theme.textPrimary
            validator: IntValidator { bottom: 0; top: 65535 }
            text: root.regValue.toString()

            background: Rectangle {
                radius: 4
                color: valueField.activeFocus ? Theme.background : Theme.surfaceLight
                border.color: valueField.activeFocus ? Theme.accent : Theme.border
                border.width: 1
            }

            onEditingFinished: {
                var value = parseInt(text)
                if (!isNaN(value)) {
                    if (root.registerType === 3)
                        modbusDataStore.setInputRegister(root.address, value)
                    else
                        modbusDataStore.setHoldingRegister(root.address, value)
                }
                focus = false
            }

            // Keep in sync when the value changes externally
            Binding {
                target: valueField
                property: "text"
                value: root.regValue.toString()
                when: !valueField.activeFocus
            }
        }

        Item { Layout.preferredWidth: 10 }

        // Hex representation
        Text {
            Layout.preferredWidth: root.hexColW
            text: Theme.toHex(root.regValue)
            color: Theme.warning
            font.family: Theme.monoFont
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 10 }

        // Inline 16-bit editor: pad shows the bit number, color shows state
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Repeater {
                model: 16

                // Wrapper adds an extra gap after each nibble
                Item {
                    id: bitCell
                    required property int index
                    readonly property int bit: 15 - index
                    readonly property bool isSet: {
                        root.dataRevision
                        return modbusDataStore.getBit(root.address, bit, root.registerType)
                    }
                    readonly property string bitName: {
                        root.metaRevision
                        return root.nameProvider ? root.nameProvider.getBitName(root.address, bit) : ""
                    }

                    width: 24 + ((index % 4 === 3 && index !== 15) ? 6 : 0)
                    height: 26

                    Rectangle {
                        width: 24
                        height: 26
                        radius: 3
                        color: bitCell.isSet ? Theme.accent : Theme.surfaceLight
                        border.color: bitCell.isSet ? Qt.lighter(Theme.accent, 1.2) : Theme.border
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: bitCell.bit
                            color: bitCell.isSet ? "#10141b" : Theme.textDisabled
                            font.family: Theme.monoFont
                            font.pixelSize: 10
                            font.bold: bitCell.isSet
                        }

                        // Marker for named bits
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 2
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.warning
                            visible: bitCell.bitName !== ""
                        }

                        HoverHandler { id: bitHover }
                        ToolTip.visible: bitHover.hovered
                        ToolTip.delay: 300
                        ToolTip.text: bitCell.bitName !== ""
                                      ? qsTr("Bit %1: %2 = %3").arg(bitCell.bit).arg(bitCell.bitName).arg(bitCell.isSet ? 1 : 0)
                                      : qsTr("Bit %1 = %2").arg(bitCell.bit).arg(bitCell.isSet ? 1 : 0)

                        TapHandler {
                            onTapped: modbusDataStore.setBit(root.address, bitCell.bit, !bitCell.isSet, root.registerType)
                        }
                    }
                }
            }
        }

        // Doubled gap between the bit editor and the Edit column
        Item { Layout.preferredWidth: 20 }

        // Edit metadata button
        AbstractButton {
            id: editButton
            Layout.preferredWidth: 56
            Layout.preferredHeight: 26
            onClicked: root.editRequested(root.address)

            background: Rectangle {
                radius: 4
                color: editButton.pressed ? Theme.accentDim
                     : editButton.hovered ? Theme.surfaceHover : Theme.surfaceLight
                border.color: editButton.hovered ? Theme.accent : Theme.border
                border.width: 1
            }

            contentItem: Text {
                text: qsTr("Edit")
                color: editButton.hovered ? Theme.textPrimary : Theme.textSecondary
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            ToolTip.visible: hovered
            ToolTip.delay: 600
            ToolTip.text: qsTr("Edit register and bit names")
        }
    }
}

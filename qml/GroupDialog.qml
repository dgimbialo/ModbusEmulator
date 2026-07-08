import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// Modal dialog for creating a named register group (address range)
Dialog {
    id: root

    signal submitted(string name, int startAddress, int endAddress)

    property int maxAddress: 29999

    title: qsTr("New register group")
    modal: true
    anchors.centerIn: parent
    width: 380
    standardButtons: Dialog.Ok | Dialog.Cancel
    Material.background: Theme.surfaceLight

    readonly property bool valid: nameField.text.trim().length > 0
                                  && startSpin.value <= endSpin.value

    onAboutToShow: {
        nameField.text = ""
        startSpin.value = 0
        endSpin.value = 15
        nameField.forceActiveFocus()
    }

    onAccepted: submitted(nameField.text.trim(), startSpin.value, endSpin.value)

    // Disable OK until the input is valid
    Component.onCompleted: {
        standardButton(Dialog.Ok).enabled = Qt.binding(function() { return root.valid })
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            text: qsTr("Group name")
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }

        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: qsTr("e.g. Recipe parameters")
            selectByMouse: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                spacing: 4
                Label {
                    text: qsTr("Start address")
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                }
                SpinBox {
                    id: startSpin
                    from: 0
                    to: root.maxAddress
                    editable: true
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                spacing: 4
                Label {
                    text: qsTr("End address")
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                }
                SpinBox {
                    id: endSpin
                    from: 0
                    to: root.maxAddress
                    editable: true
                    Layout.fillWidth: true
                }
            }
        }

        Label {
            visible: startSpin.value > endSpin.value
            text: qsTr("Start address must not exceed end address")
            color: Theme.error
            font.pixelSize: Theme.fontSizeSmall
        }

        Label {
            text: qsTr("Registers in group: %1").arg(Math.max(0, endSpin.value - startSpin.value + 1))
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}

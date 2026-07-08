import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// Grid of LED-style toggle cells for Coils or Discrete Inputs,
// organized in named address groups (like the register views).
Item {
    id: root

    property bool isCoil: true      // false = discrete inputs
    readonly property int maxAddress: isCoil ? 4999 : 9999
    property var defaultGroups: []  // [{name, startAddress, endAddress}]

    // 0 = "All Groups", 1..N = groupsModel index + 1
    property int currentGroupIndex: 0
    property var visibleAddresses: []
    property int dataRevision: 0

    ListModel { id: groupsModel }

    // Combo entries: "All Groups" + every group name
    function comboEntries() {
        var names = [qsTr("All Groups")]
        for (var i = 0; i < groupsModel.count; ++i)
            names.push(groupsModel.get(i).name)
        return names
    }

    Component.onCompleted: importGroups(null)

    Connections {
        target: modbusDataStore
        function onDataChanged() { root.dataRevision++ }
    }

    // Project file integration
    function exportGroups() {
        var arr = []
        for (var i = 0; i < groupsModel.count; ++i) {
            var g = groupsModel.get(i)
            arr.push({ name: g.name, startAddress: g.startAddress, endAddress: g.endAddress })
        }
        return arr
    }

    function importGroups(arr) {
        if (!arr || !arr.length)
            arr = root.defaultGroups

        groupsModel.clear()
        for (var i = 0; i < arr.length; ++i) {
            groupsModel.append({
                name: String(arr[i].name),
                startAddress: Number(arr[i].startAddress),
                endAddress: Number(arr[i].endAddress)
            })
        }
        currentGroupIndex = 0
        groupCombo.model = comboEntries()
        groupCombo.currentIndex = 0
        rebuildAddresses()
    }

    function refreshCombo() {
        groupCombo.model = comboEntries()
        groupCombo.currentIndex = root.currentGroupIndex
    }

    function rebuildAddresses() {
        var list = []
        if (currentGroupIndex === 0) {
            // Union of every group, sorted, without duplicates
            var seen = {}
            for (var g = 0; g < groupsModel.count; ++g) {
                var gr = groupsModel.get(g)
                for (var a = gr.startAddress; a <= gr.endAddress; ++a) {
                    if (!seen[a]) { seen[a] = true; list.push(a) }
                }
            }
            list.sort(function(x, y) { return x - y })
        } else if (currentGroupIndex - 1 < groupsModel.count) {
            var gr2 = groupsModel.get(currentGroupIndex - 1)
            for (var b = gr2.startAddress; b <= gr2.endAddress; ++b)
                list.push(b)
        }
        visibleAddresses = list
    }

    function bitValue(address) {
        dataRevision
        return isCoil ? modbusDataStore.getCoil(address)
                      : modbusDataStore.getDiscreteInput(address)
    }

    function setBitValue(address, value) {
        if (isCoil)
            modbusDataStore.setCoil(address, value)
        else
            modbusDataStore.setDiscreteInput(address, value)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        // Toolbar: group selector + management
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: qsTr("Group")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeNormal
            }

            ComboBox {
                id: groupCombo
                Layout.preferredWidth: 220
                model: root.comboEntries()
                onActivated: {
                    root.currentGroupIndex = currentIndex
                    root.rebuildAddresses()
                }
            }

            Button {
                text: qsTr("Add")
                flat: true
                onClicked: groupDialog.open()
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: qsTr("Add group")
            }

            Button {
                text: qsTr("Delete")
                flat: true
                Material.foreground: enabled ? Theme.error : undefined
                enabled: root.currentGroupIndex > 0 && groupsModel.count > 1
                onClicked: {
                    groupsModel.remove(root.currentGroupIndex - 1)
                    root.currentGroupIndex = 0
                    root.refreshCombo()
                    root.rebuildAddresses()
                }
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: qsTr("Remove current group")
            }

            // Range chip
            Rectangle {
                Layout.preferredHeight: 26
                Layout.preferredWidth: rangeText.implicitWidth + 20
                radius: 13
                color: Theme.surfaceLight
                border.color: Theme.border

                Text {
                    id: rangeText
                    anchors.centerIn: parent
                    text: {
                        if (root.currentGroupIndex === 0)
                            return qsTr("%1 items").arg(root.visibleAddresses.length)
                        if (root.currentGroupIndex - 1 < groupsModel.count) {
                            var g = groupsModel.get(root.currentGroupIndex - 1)
                            return g.startAddress + " – " + g.endAddress
                        }
                        return ""
                    }
                    color: Theme.textSecondary
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("All ON")
                flat: true
                onClicked: {
                    for (var i = 0; i < root.visibleAddresses.length; ++i)
                        root.setBitValue(root.visibleAddresses[i], true)
                }
            }

            Button {
                text: qsTr("All OFF")
                flat: true
                onClicked: {
                    for (var i = 0; i < root.visibleAddresses.length; ++i)
                        root.setBitValue(root.visibleAddresses[i], false)
                }
            }
        }

        // LED grid
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.visibleAddresses
            cellWidth: 70
            cellHeight: 46

            ScrollBar.vertical: ScrollBar { }

            delegate: Item {
                required property var modelData
                readonly property int address: modelData
                readonly property bool isOn: root.bitValue(address)

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    id: cell
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 5
                    color: cellHover.hovered ? Theme.surfaceHover : Theme.surface
                    border.color: isOn ? Theme.success : Theme.border
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    HoverHandler { id: cellHover }

                    TapHandler {
                        onTapped: root.setBitValue(address, !isOn)
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 3

                        // LED
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 12
                            height: 12
                            radius: 6
                            color: isOn ? Theme.success : Theme.surfaceLight
                            border.color: isOn ? Qt.lighter(Theme.success, 1.3) : Theme.border
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: address
                            color: isOn ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.monoFont
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: qsTr("No addresses in this group")
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeNormal
            }
        }
    }

    GroupDialog {
        id: groupDialog
        parent: Overlay.overlay
        maxAddress: root.maxAddress
        onSubmitted: function(name, startAddress, endAddress) {
            groupsModel.append({ name: name, startAddress: startAddress, endAddress: endAddress })
            root.currentGroupIndex = groupsModel.count   // select the new group (offset by "All Groups")
            root.refreshCombo()
            root.rebuildAddresses()
        }
    }
}

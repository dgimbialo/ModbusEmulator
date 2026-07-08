import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// Register table for one register type (holding or input) with named
// address groups (stored in the project file), an "All Groups" view,
// live filtering, a column header and compact rows with an inline bit editor.
Item {
    id: root

    property int registerType: 4                   // 3 = Input, 4 = Holding
    property var defaultGroups: []                 // [{name, startAddress, endAddress}]

    // 0 = "All Groups", 1..N = groupsModel index + 1
    property int currentGroupIndex: 0
    property var visibleAddresses: []   // [{ addr, brk }] - brk marks a group boundary
    property int dataRevision: 0

    // Column widths - adjustable by dragging the header splitters
    property int addressColW: 76
    property int nameColW: 130
    property int valueColW: 84
    property int hexColW: 76
    readonly property int bitsColW: 432
    readonly property int editColW: 56

    // Register metadata: { "<address>": { name: "...", bits: { "<bit>": "..." } } }
    property var registerMeta: ({})
    property int metaRevision: 0

    function getRegisterName(address) {
        var m = registerMeta[String(address)]
        return m && m.name ? m.name : ""
    }

    function getBitName(address, bit) {
        var m = registerMeta[String(address)]
        return (m && m.bits && m.bits[String(bit)]) ? m.bits[String(bit)] : ""
    }

    function setRegisterMeta(address, name, bits) {
        var key = String(address)
        if ((!name || name === "") && (!bits || Object.keys(bits).length === 0))
            delete registerMeta[key]
        else
            registerMeta[key] = { name: name || "", bits: bits || {} }
        metaRevision++
    }

    function exportMeta() {
        return registerMeta
    }

    function importMeta(obj) {
        var meta = {}
        if (obj) {
            for (var key in obj) {
                var src = obj[key]
                if (!src)
                    continue
                var bits = {}
                if (src.bits) {
                    for (var b in src.bits) {
                        if (src.bits[b])
                            bits[b] = String(src.bits[b])
                    }
                }
                var name = src.name ? String(src.name) : ""
                if (name !== "" || Object.keys(bits).length > 0)
                    meta[key] = { name: name, bits: bits }
            }
        }
        registerMeta = meta
        metaRevision++
    }

    ListModel { id: groupsModel }

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

    // Project file integration: groups are part of the saved project
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
        refreshCombo()
        rebuildAddresses()
    }

    function refreshCombo() {
        groupCombo.model = comboEntries()
        groupCombo.currentIndex = root.currentGroupIndex
    }

    function rebuildAddresses() {
        var filter = filterField.text.trim()
        var list = []

        function pushRange(start, end, seen) {
            for (var a = start; a <= end; ++a) {
                if (seen) {
                    if (seen[a])
                        continue
                    seen[a] = true
                }
                if (filter === "" || String(a).indexOf(filter) !== -1)
                    list.push(a)
            }
        }

        if (currentGroupIndex === 0) {
            // Union of every group, sorted, without duplicates
            var seen = {}
            for (var g = 0; g < groupsModel.count; ++g) {
                var gr = groupsModel.get(g)
                pushRange(gr.startAddress, gr.endAddress, seen)
            }
            list.sort(function(x, y) { return x - y })
        } else if (currentGroupIndex - 1 < groupsModel.count) {
            var gr2 = groupsModel.get(currentGroupIndex - 1)
            pushRange(gr2.startAddress, gr2.endAddress, null)
        }

        // Mark group boundaries (address jumps) so the list can render a
        // visual gap between groups. Skipped while filtering - a filtered
        // list is full of jumps that are not group boundaries.
        var items = []
        for (var i = 0; i < list.length; ++i) {
            items.push({
                addr: list[i],
                brk: filter === "" && i > 0 && list[i] > list[i - 1] + 1
            })
        }
        visibleAddresses = items
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        // Toolbar: group selector + management + search
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
                ToolTip.text: qsTr("Add register group")
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
                            return qsTr("%1 registers").arg(root.visibleAddresses.length)
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

            // Address filter
            TextField {
                id: filterField
                Layout.preferredWidth: 180
                placeholderText: qsTr("Filter by address...")
                leftPadding: 30
                onTextChanged: root.rebuildAddresses()

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "🔍"
                    font.pixelSize: 12
                    opacity: 0.6
                }
            }
        }

        // Column header (matches the delegate layout below).
        // The splitters between columns are draggable to resize them.
        Item {
            Layout.fillWidth: true
            height: 28

            // Draggable boundary that resizes the column to its left
            component ColumnSplitter: Item {
                id: splitter
                property string targetProperty: ""
                width: 10
                height: 26

                Rectangle {
                    anchors.centerIn: parent
                    width: 2
                    height: 16
                    radius: 1
                    color: splitterArea.containsMouse || splitterArea.pressed ? Theme.accent : Theme.border
                }

                MouseArea {
                    id: splitterArea
                    anchors.fill: parent
                    anchors.margins: -3   // easier to grab
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    preventStealing: true

                    property real pressGlobalX: 0
                    property int pressWidth: 0

                    onPressed: function(mouse) {
                        pressGlobalX = splitterArea.mapToGlobal(mouse.x, 0).x
                        pressWidth = root[splitter.targetProperty]
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed)
                            return
                        var dx = splitterArea.mapToGlobal(mouse.x, 0).x - pressGlobalX
                        root[splitter.targetProperty] = Math.max(50, Math.min(400, pressWidth + dx))
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 20
                spacing: 0

                Text {
                    Layout.preferredWidth: root.addressColW
                    text: qsTr("Address")
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                ColumnSplitter { targetProperty: "addressColW" }

                Text {
                    Layout.preferredWidth: root.nameColW
                    text: qsTr("Name")
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                ColumnSplitter { targetProperty: "nameColW" }

                Text {
                    Layout.preferredWidth: root.valueColW
                    text: qsTr("Value")
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                ColumnSplitter { targetProperty: "valueColW" }

                Text {
                    Layout.preferredWidth: root.hexColW
                    text: qsTr("Hex")
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                ColumnSplitter { targetProperty: "hexColW" }

                Item { Layout.fillWidth: true; Layout.minimumWidth: 10 }

                Text {
                    text: qsTr("Bits  15 … 0")
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: root.bitsColW
                }

                // Doubled gap between the bit editor and the Edit column
                Item { Layout.preferredWidth: 20 }

                Text {
                    Layout.preferredWidth: root.editColW
                    text: qsTr("Edit")
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.border
            }
        }

        // Register list
        ListView {
            id: registerList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.visibleAddresses
            spacing: 3
            clip: true
            reuseItems: false

            ScrollBar.vertical: ScrollBar { }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
            }

            delegate: Item {
                id: rowWrapper
                required property var modelData
                width: registerList.width - 12
                // Extra top gap marks the boundary between register groups
                height: 34 + (modelData.brk ? 16 : 0)

                RegisterDelegate {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 34
                    address: rowWrapper.modelData.addr
                    registerType: root.registerType
                    dataRevision: root.dataRevision
                    metaRevision: root.metaRevision
                    nameProvider: root
                    addressColW: root.addressColW
                    nameColW: root.nameColW
                    valueColW: root.valueColW
                    hexColW: root.hexColW
                    onEditRequested: function(addr) {
                        var m = root.registerMeta[String(addr)]
                        nameDialog.openFor(addr, m ? m.name : "", m ? m.bits : null)
                    }
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: registerList.count === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "▦"
                    font.pixelSize: 42
                    color: Theme.textDisabled
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: filterField.text.length > 0
                          ? qsTr("No registers match the filter")
                          : qsTr("No registers in this group")
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontSizeNormal
                }
            }
        }
    }

    GroupDialog {
        id: groupDialog
        parent: Overlay.overlay
        onSubmitted: function(name, startAddress, endAddress) {
            groupsModel.append({ name: name, startAddress: startAddress, endAddress: endAddress })
            root.currentGroupIndex = groupsModel.count   // select the new group (offset by "All Groups")
            root.refreshCombo()
            root.rebuildAddresses()
        }
    }

    RegisterNameDialog {
        id: nameDialog
        parent: Overlay.overlay
        typeName: root.registerType === 3 ? qsTr("Input") : qsTr("Holding")
        onSubmitted: function(address, name, bits) {
            root.setRegisterMeta(address, name, bits)
        }
    }
}

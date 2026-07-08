import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// Signal generator: feeds registers with sine / square / ramp / random /
// increment waveforms so a connected Modbus master sees live process data.
Item {
    id: root

    property int dataRevision: 0

    Connections {
        target: modbusDataStore
        function onDataChanged() { root.dataRevision++ }
    }

    ListModel { id: simulators }

    // Project file integration
    function exportState() {
        var gens = []
        for (var i = 0; i < simulators.count; ++i) {
            var s = simulators.get(i)
            gens.push({
                name: s.name, waveform: s.waveform, targetType: s.targetType,
                address: s.address, minVal: s.minVal, maxVal: s.maxVal,
                period: s.period, active: s.active
            })
        }
        return { interval: intervalSlider.value, generators: gens }
    }

    function importState(state) {
        masterSwitch.checked = false
        simulators.clear()
        if (!state) {
            intervalSlider.value = 200
            return
        }
        intervalSlider.value = Number(state.interval) || 200
        var gens = state.generators || []
        for (var i = 0; i < gens.length; ++i) {
            simulators.append({
                name: String(gens[i].name),
                waveform: String(gens[i].waveform),
                targetType: Number(gens[i].targetType),
                address: Number(gens[i].address),
                minVal: Number(gens[i].minVal),
                maxVal: Number(gens[i].maxVal),
                period: Number(gens[i].period),
                active: gens[i].active === true
            })
        }
    }

    function waveformGlyph(waveform) {
        switch (waveform) {
        case "Sine":      return "∿"
        case "Square":    return "⎍"
        case "Ramp":      return "╱"
        case "Random":    return "⚄"
        case "Increment": return "↑"
        }
        return "?"
    }

    function currentValue(sim) {
        return sim.targetType === 3 ? modbusDataStore.getInputRegister(sim.address)
                                    : modbusDataStore.getHoldingRegister(sim.address)
    }

    function writeValue(sim, value) {
        var v = Math.round(Math.max(0, Math.min(65535, value)))
        if (sim.targetType === 3)
            modbusDataStore.setInputRegister(sim.address, v)
        else
            modbusDataStore.setHoldingRegister(sim.address, v)
    }

    Timer {
        id: engine
        interval: intervalSlider.value
        repeat: true
        running: masterSwitch.checked && simulators.count > 0
        onTriggered: {
            var now = Date.now()
            for (var i = 0; i < simulators.count; ++i) {
                var sim = simulators.get(i)
                if (!sim.active)
                    continue

                var span = sim.maxVal - sim.minVal
                var t = (now % sim.period) / sim.period
                var value = sim.minVal

                switch (sim.waveform) {
                case "Sine":
                    value = sim.minVal + span * (0.5 + 0.5 * Math.sin(2 * Math.PI * t))
                    break
                case "Square":
                    value = t < 0.5 ? sim.maxVal : sim.minVal
                    break
                case "Ramp":
                    value = sim.minVal + span * t
                    break
                case "Random":
                    value = sim.minVal + span * Math.random()
                    break
                case "Increment":
                    var current = root.currentValue(sim)
                    value = current + 1
                    if (value > sim.maxVal)
                        value = sim.minVal
                    break
                }
                root.writeValue(sim, value)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        // Engine controls
        Frame {
            Layout.fillWidth: true
            Material.background: Theme.surface

            RowLayout {
                anchors.fill: parent
                spacing: 16

                Switch {
                    id: masterSwitch
                    text: qsTr("Simulation engine")
                    checked: false
                }

                Label {
                    text: qsTr("Update interval")
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeNormal
                }

                Slider {
                    id: intervalSlider
                    Layout.preferredWidth: 200
                    from: 50
                    to: 1000
                    stepSize: 50
                    value: 200
                }

                Label {
                    text: intervalSlider.value + " ms"
                    color: Theme.textPrimary
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSizeNormal
                    Layout.preferredWidth: 64
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Add generator")
                    highlighted: true
                    onClicked: addDialog.openForAdd()
                }
            }
        }

        // Generator cards
        ListView {
            id: simList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: simulators
            spacing: 8
            clip: true

            ScrollBar.vertical: ScrollBar { }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 200 }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 150 }
            }

            delegate: Rectangle {
                id: card
                required property int index
                required property string name
                required property string waveform
                required property int targetType
                required property int address
                required property int minVal
                required property int maxVal
                required property int period
                required property bool active

                width: simList.width - 12
                height: 68
                radius: Theme.radius
                color: Theme.surface
                border.color: active && masterSwitch.checked ? Theme.accentDim : Theme.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 14

                    // Waveform glyph
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: Theme.surfaceLight
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: root.waveformGlyph(card.waveform)
                            color: Theme.accent
                            font.pixelSize: 18
                        }
                    }

                    // Description
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: card.name
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeNormal
                            font.bold: true
                        }

                        Text {
                            text: qsTr("%1 · %2 @ %3 · range %4–%5 · %6 ms")
                                  .arg(card.waveform)
                                  .arg(card.targetType === 3 ? qsTr("Input") : qsTr("Holding"))
                                  .arg(card.address)
                                  .arg(card.minVal)
                                  .arg(card.maxVal)
                                  .arg(card.period)
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    // Live value
                    Text {
                        text: {
                            root.dataRevision
                            return root.currentValue(card)
                        }
                        color: card.active && masterSwitch.checked ? Theme.success : Theme.textDisabled
                        font.family: Theme.monoFont
                        font.pixelSize: 20
                        font.bold: true
                        Layout.preferredWidth: 70
                        horizontalAlignment: Text.AlignRight
                    }

                    Switch {
                        checked: card.active
                        onToggled: simulators.setProperty(card.index, "active", checked)
                    }

                    Button {
                        text: qsTr("Edit")
                        flat: true
                        onClicked: addDialog.openForEdit(card.index)
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: qsTr("Edit this generator")
                    }

                    RoundButton {
                        text: "✕"
                        flat: true
                        implicitWidth: 56
                        implicitHeight: 56
                        font.pixelSize: 22
                        Material.foreground: Theme.error
                        onClicked: simulators.remove(card.index)
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: qsTr("Delete this generator")
                    }
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: simulators.count === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "∿"
                    font.pixelSize: 48
                    color: Theme.textDisabled
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("No signal generators yet")
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeLarge
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Add one to feed live waveforms into your registers")
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontSizeNormal
                }
            }
        }
    }

    // Generator editor dialog (used both for adding and editing)
    Dialog {
        id: addDialog
        title: editIndex >= 0 ? qsTr("Edit signal generator") : qsTr("New signal generator")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 420
        standardButtons: Dialog.Ok | Dialog.Cancel
        Material.background: Theme.surfaceLight

        property int editIndex: -1

        function openForAdd() {
            editIndex = -1
            simNameField.text = qsTr("Generator %1").arg(simulators.count + 1)
            waveformCombo.currentIndex = 0
            targetCombo.currentIndex = 0
            addressSpin.value = 0
            minSpin.value = 0
            maxSpin.value = 100
            periodSpin.value = 2000
            open()
        }

        function openForEdit(index) {
            editIndex = index
            var s = simulators.get(index)
            simNameField.text = s.name
            waveformCombo.currentIndex = Math.max(0, waveformCombo.find(s.waveform))
            targetCombo.currentIndex = s.targetType === 3 ? 0 : 1
            addressSpin.value = s.address
            minSpin.value = s.minVal
            maxSpin.value = s.maxVal
            periodSpin.value = s.period
            open()
        }

        onAccepted: {
            var data = {
                name: simNameField.text.trim() === "" ? qsTr("Generator") : simNameField.text.trim(),
                waveform: waveformCombo.currentText,
                targetType: targetCombo.currentIndex === 0 ? 3 : 4,
                address: addressSpin.value,
                minVal: Math.min(minSpin.value, maxSpin.value),
                maxVal: Math.max(minSpin.value, maxSpin.value),
                period: periodSpin.value,
                active: true
            }
            if (editIndex >= 0) {
                data.active = simulators.get(editIndex).active
                simulators.set(editIndex, data)
            } else {
                simulators.append(data)
            }
        }

        GridLayout {
            anchors.fill: parent
            columns: 2
            columnSpacing: 12
            rowSpacing: 10

            Label { text: qsTr("Name"); color: Theme.textSecondary }
            TextField {
                id: simNameField
                Layout.fillWidth: true
                selectByMouse: true
            }

            Label { text: qsTr("Waveform"); color: Theme.textSecondary }
            ComboBox {
                id: waveformCombo
                Layout.fillWidth: true
                model: ["Sine", "Square", "Ramp", "Random", "Increment"]
            }

            Label { text: qsTr("Target"); color: Theme.textSecondary }
            ComboBox {
                id: targetCombo
                Layout.fillWidth: true
                model: [qsTr("Input register"), qsTr("Holding register")]
            }

            Label { text: qsTr("Address"); color: Theme.textSecondary }
            SpinBox {
                id: addressSpin
                Layout.fillWidth: true
                from: 0; to: 29999
                editable: true
            }

            Label { text: qsTr("Min value"); color: Theme.textSecondary }
            SpinBox {
                id: minSpin
                Layout.fillWidth: true
                from: 0; to: 65535
                editable: true
            }

            Label { text: qsTr("Max value"); color: Theme.textSecondary }
            SpinBox {
                id: maxSpin
                Layout.fillWidth: true
                from: 0; to: 65535
                value: 100
                editable: true
            }

            Label { text: qsTr("Period, ms"); color: Theme.textSecondary }
            SpinBox {
                id: periodSpin
                Layout.fillWidth: true
                from: 100; to: 60000
                stepSize: 100
                value: 2000
                editable: true
            }
        }
    }
}

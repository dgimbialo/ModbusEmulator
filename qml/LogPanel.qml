import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Console panel with severity filter, copy/clear actions and smart auto-scroll
Rectangle {
    id: root
    color: "#0c0f14"

    property string levelFilter: "All"

    readonly property var filteredEntries: {
        var entries = logHandler.logEntries
        if (levelFilter === "All")
            return entries
        var tag = "[" + levelFilter.toUpperCase() + "]"
        var out = []
        for (var i = 0; i < entries.length; ++i) {
            if (entries[i].indexOf(tag) !== -1)
                out.push(entries[i])
        }
        return out
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        // Header row
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: qsTr("Console")
                font.bold: true
                font.pixelSize: Theme.fontSizeNormal
                color: Theme.textPrimary
            }

            Rectangle {
                Layout.preferredWidth: countText.implicitWidth + 14
                Layout.preferredHeight: 18
                radius: 9
                color: Theme.surfaceLight

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: root.filteredEntries.length
                    color: Theme.textSecondary
                    font.pixelSize: 10
                    font.family: Theme.monoFont
                }
            }

            Item { Layout.preferredWidth: 12 }

            // Severity filter buttons
            Row {
                spacing: 2

                Repeater {
                    model: ["All", "Debug", "Warning", "Critical"]

                    delegate: AbstractButton {
                        required property string modelData
                        readonly property bool selected: root.levelFilter === modelData

                        width: filterLabel.implicitWidth + 24
                        height: 30
                        onClicked: root.levelFilter = modelData

                        background: Rectangle {
                            radius: 15
                            color: selected ? Theme.accentDim : "transparent"
                            border.color: selected ? Theme.accent : Theme.border
                            border.width: 1
                        }

                        contentItem: Text {
                            id: filterLabel
                            text: modelData
                            color: selected ? Theme.textPrimary : Theme.textSecondary
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Switch {
                id: autoScrollSwitch
                text: qsTr("Auto-scroll")
                checked: true
                font.pixelSize: 15
            }

            ToolButton {
                text: qsTr("Copy")
                font.pixelSize: 16
                implicitHeight: 36
                onClicked: logHandler.copyToClipboard()
            }

            ToolButton {
                text: qsTr("Clear")
                font.pixelSize: 16
                implicitHeight: 36
                onClicked: logHandler.clearLog()
            }
        }

        // Log entries
        ListView {
            id: logView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filteredEntries
            spacing: 1

            ScrollBar.vertical: ScrollBar { }

            onCountChanged: {
                if (autoScrollSwitch.checked)
                    Qt.callLater(positionViewAtEnd)
            }

            delegate: Text {
                required property string modelData
                width: logView.width
                text: modelData
                color: Theme.levelColor(modelData)
                font.family: Theme.monoFont
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Text {
                anchors.centerIn: parent
                visible: logView.count === 0
                text: qsTr("Log is empty")
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeNormal
            }
        }
    }
}

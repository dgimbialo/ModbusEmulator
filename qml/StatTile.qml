import QtQuick
import QtQuick.Layouts

// Dashboard metric card: big value + caption + colored accent stripe
Rectangle {
    id: root
    property string caption: ""
    property string value: "0"
    property string glyph: ""
    property color accentColor: Theme.accent

    implicitHeight: 92
    radius: Theme.radius
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 1
        width: 4
        radius: 2
        color: root.accentColor
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 14
        spacing: 12

        Text {
            text: root.glyph
            font.pixelSize: 26
            color: root.accentColor
            visible: root.glyph !== ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.value
                color: Theme.textPrimary
                font.pixelSize: 24
                font.bold: true
                font.family: Theme.monoFont
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.caption
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}

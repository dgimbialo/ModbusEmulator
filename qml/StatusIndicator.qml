import QtQuick

// Pulsing status LED - green pulse while the server is online
Item {
    id: root
    property bool active: false
    implicitWidth: 16
    implicitHeight: 16

    // Soft halo behind the LED
    Rectangle {
        id: halo
        anchors.centerIn: parent
        width: 16
        height: 16
        radius: width / 2
        color: root.active ? Theme.success : Theme.error
        opacity: 0.25

        SequentialAnimation on scale {
            running: root.active
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.8; duration: 900; easing.type: Easing.OutQuad }
            NumberAnimation { from: 1.8; to: 1.0; duration: 900; easing.type: Easing.InQuad }
        }
    }

    // LED core
    Rectangle {
        anchors.centerIn: parent
        width: 10
        height: 10
        radius: 5
        color: root.active ? Theme.success : Theme.error
        border.color: Qt.lighter(color, 1.3)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 300 } }
    }
}

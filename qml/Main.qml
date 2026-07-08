import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Dialogs

ApplicationWindow {
    id: window
    visible: true
    width: 1280
    height: 840
    minimumWidth: 1000
    minimumHeight: 660
    title: qsTr("Modbus Slave Emulator") + " - " + projectManager.currentFileName

    Material.theme: Material.Dark
    Material.accent: Theme.accent
    Material.primary: Theme.surface
    color: Theme.background

    // ---------- Project file handling ----------

    // Gather everything the QML layer owns for the project file
    function collectUiState() {
        return {
            holdingGroups: holdingView.exportGroups(),
            inputGroups: inputView.exportGroups(),
            coilGroups: coilsView.exportGroups(),
            discreteGroups: discreteView.exportGroups(),
            holdingMeta: holdingView.exportMeta(),
            inputMeta: inputView.exportMeta(),
            simulation: simPanel.exportState()
        }
    }

    function applyUiState(ui) {
        holdingView.importGroups(ui ? ui.holdingGroups : null)
        inputView.importGroups(ui ? ui.inputGroups : null)
        coilsView.importGroups(ui ? ui.coilGroups : null)
        discreteView.importGroups(ui ? ui.discreteGroups : null)
        holdingView.importMeta(ui ? ui.holdingMeta : null)
        inputView.importMeta(ui ? ui.inputMeta : null)
        simPanel.importState(ui ? ui.simulation : null)
    }

    function newProject() {
        projectManager.closeProject()
        applyUiState(null)
    }

    function saveProject() {
        if (projectManager.currentFile === "")
            saveDialog.open()
        else
            projectManager.save(collectUiState())
    }

    function openLoadedDocument(doc) {
        if (doc && doc.fileType)
            applyUiState(doc.ui)
    }

    // Deferred so it runs after every child's own Component.onCompleted
    // (the completion order between objects is not guaranteed in QML)
    Component.onCompleted: Qt.callLater(function() {
        openLoadedDocument(projectManager.openLast())
    })

    FileDialog {
        id: saveDialog
        title: qsTr("Save project")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("Modbus project (*.json)"), qsTr("All files (*)")]
        defaultSuffix: "json"
        onAccepted: projectManager.saveToFile(selectedFile, window.collectUiState())
    }

    FileDialog {
        id: openDialog
        title: qsTr("Open project")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Modbus project (*.json)"), qsTr("All files (*)")]
        onAccepted: window.openLoadedDocument(projectManager.openFile(selectedFile))
    }

    Shortcut { sequence: StandardKey.New;  context: Qt.ApplicationShortcut; onActivated: window.newProject() }
    Shortcut { sequence: StandardKey.Open; context: Qt.ApplicationShortcut; onActivated: openDialog.open() }
    Shortcut { sequence: StandardKey.Save; context: Qt.ApplicationShortcut; onActivated: window.saveProject() }
    Shortcut { sequence: "Ctrl+Shift+S";   context: Qt.ApplicationShortcut; onActivated: saveDialog.open() }

    // ---------- Header ----------
    header: ToolBar {
        height: Theme.headerHeight
        Material.background: Theme.surface

        // Bottom separator line
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 14

            // Project menu
            ToolButton {
                text: qsTr("Project ▾")
                font.pixelSize: Theme.fontSizeNormal
                onClicked: projectMenu.open()

                Menu {
                    id: projectMenu
                    y: parent.height
                    Material.background: Theme.surfaceLight

                    Action {
                        text: qsTr("New")
                        onTriggered: window.newProject()
                    }
                    Action {
                        text: qsTr("Open...")
                        onTriggered: openDialog.open()
                    }
                    MenuSeparator { }
                    Action {
                        text: qsTr("Save")
                        onTriggered: window.saveProject()
                    }
                    Action {
                        text: qsTr("Save As...")
                        onTriggered: saveDialog.open()
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Connection status
            StatusIndicator {
                active: modbusServer.running
            }

            Label {
                text: modbusServer.running ? qsTr("Online") : qsTr("Offline")
                color: modbusServer.running ? Theme.success : Theme.textSecondary
                font.pixelSize: Theme.fontSizeNormal
                font.bold: true
            }

            Item { width: 8 }

            // Start / stop
            Button {
                text: modbusServer.running ? qsTr("Stop") : qsTr("Start")
                highlighted: !modbusServer.running
                Material.background: modbusServer.running ? Theme.error : undefined
                onClicked: {
                    if (modbusServer.running) {
                        modbusServer.stop()
                    } else if (!modbusServer.start()) {
                        connectionDrawer.open()
                    }
                }
            }

            // Settings
            ToolButton {
                text: "⚙"
                font.pixelSize: 20
                onClicked: connectionDrawer.open()
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: qsTr("Connection settings")
            }
        }
    }

    ConnectionDrawer {
        id: connectionDrawer
        height: window.height
    }

    // ---------- Main content ----------
    SplitView {
        anchors.fill: parent
        orientation: Qt.Vertical

        handle: Rectangle {
            implicitHeight: 5
            color: SplitHandle.pressed ? Theme.accent
                 : SplitHandle.hovered ? Theme.accentDim : Theme.background
        }

        ColumnLayout {
            SplitView.fillHeight: true
            SplitView.minimumHeight: 320
            spacing: 0

            TabBar {
                id: mainTabs
                Layout.fillWidth: true
                Material.background: Theme.surface

                TabButton { text: qsTr("Holding Registers"); width: implicitWidth }
                TabButton { text: qsTr("Input Registers"); width: implicitWidth }
                TabButton { text: qsTr("Coils"); width: implicitWidth }
                TabButton { text: qsTr("Discrete Inputs"); width: implicitWidth }
                TabButton { text: qsTr("Simulation"); width: implicitWidth }
                TabButton { text: qsTr("Dashboard"); width: implicitWidth }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: mainTabs.currentIndex

                RegisterView {
                    id: holdingView
                    registerType: 4
                    defaultGroups: [
                        { name: qsTr("Default Holding"), startAddress: 19993, endAddress: 20022 },
                        { name: qsTr("Recipe"), startAddress: 100, endAddress: 400 }
                    ]
                }

                RegisterView {
                    id: inputView
                    registerType: 3
                    defaultGroups: [
                        { name: qsTr("Default Input"), startAddress: 0, endAddress: 15 }
                    ]
                }

                CoilsView {
                    id: coilsView
                    isCoil: true
                    defaultGroups: [
                        { name: qsTr("Default Coils"), startAddress: 0, endAddress: 63 }
                    ]
                }

                CoilsView {
                    id: discreteView
                    isCoil: false
                    defaultGroups: [
                        { name: qsTr("Default Discrete"), startAddress: 0, endAddress: 63 }
                    ]
                }

                SimulationPanel { id: simPanel }

                DashboardView { }
            }
        }

        // Console at the bottom
        LogPanel {
            SplitView.preferredHeight: 190
            SplitView.minimumHeight: 60
        }
    }

    // ---------- Footer status bar ----------
    footer: Rectangle {
        height: 28
        color: Theme.surface

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Theme.border
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 18

            Label {
                text: modbusServer.statusText
                color: modbusServer.running ? Theme.success
                     : modbusServer.lastError !== "" ? Theme.error : Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.maximumWidth: window.width * 0.5
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "RX " + modbusServer.readRequests
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.monoFont
            }

            Label {
                text: "TX " + modbusServer.writeRequests
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.monoFont
            }

            Label {
                text: qsTr("ERR ") + modbusServer.errorCount
                color: modbusServer.errorCount > 0 ? Theme.error : Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.monoFont
            }

            Label {
                id: clockLabel
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.monoFont

                Timer {
                    interval: 1000
                    repeat: true
                    running: true
                    triggeredOnStart: true
                    onTriggered: clockLabel.text = new Date().toLocaleTimeString(Qt.locale(), "hh:mm:ss")
                }
            }
        }
    }
}

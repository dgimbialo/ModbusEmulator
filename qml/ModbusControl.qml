import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: root
    width: parent.width
    height: parent.height
    color: "lightgray"
    
    // Store register groups
    property var holdingRegisterGroups: ListModel {
        ListElement { 
            name: "Default Holding"; 
            startRegister: 19993; 
            endRegister: 20022 
        }
        ListElement { 
            name: "Recipe"; 
            startRegister: 100; 
            endRegister: 400 
        }
    }
    
    property var inputRegisterGroups: ListModel {
        ListElement { 
            name: "Default Input"; 
            startRegister: 0; 
            endRegister: 15 
        }
    }
    
    // Track currently selected groups
    property int selectedHoldingGroupIndex: 0
    property int selectedInputGroupIndex: 0
    
    // Calculated properties for current ranges
    property int holdingStartRegister: 0
    property int holdingEndRegister: 0
    property int inputStartRegister: 0
    property int inputEndRegister: 0
    
    // Update register ranges when component is completed
    Component.onCompleted: {
        updateHoldingRegisters();
        updateInputRegisters();
    }
    
    // Functions to update register ranges
    function updateHoldingRegisters() {
        if (selectedHoldingGroupIndex >= 0 && selectedHoldingGroupIndex < holdingRegisterGroups.count) {
            holdingStartRegister = holdingRegisterGroups.get(selectedHoldingGroupIndex).startRegister;
            holdingEndRegister = holdingRegisterGroups.get(selectedHoldingGroupIndex).endRegister;
        }
    }
    
    function updateInputRegisters() {
        if (selectedInputGroupIndex >= 0 && selectedInputGroupIndex < inputRegisterGroups.count) {
            inputStartRegister = inputRegisterGroups.get(selectedInputGroupIndex).startRegister;
            inputEndRegister = inputRegisterGroups.get(selectedInputGroupIndex).endRegister;
        }
    }
    
    // Property to control log panel height
    property real logPanelHeight: 150
    
    // Dialog for adding new register groups
    Dialog {
        id: addGroupDialog
        title: "Add Register Group"
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 400
        
        property bool isHoldingGroup: true
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            
            RowLayout {
                Layout.fillWidth: true
                
                Text { text: "Group Name:" }
                TextField { 
                    id: groupNameField
                    Layout.fillWidth: true
                    placeholderText: "Enter group name"
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                
                Text { text: "Register Type:" }
                ComboBox {
                    id: registerTypeCombo
                    model: ["Holding Registers", "Input Registers"]
                    onCurrentIndexChanged: {
                        addGroupDialog.isHoldingGroup = (currentIndex === 0)
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                
                Text { text: "Start Register:" }
                SpinBox {
                    id: startRegisterField
                    Layout.fillWidth: true
                    from: 0
                    to: 65535
                    editable: true
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                
                Text { text: "End Register:" }
                SpinBox {
                    id: endRegisterField
                    Layout.fillWidth: true
                    from: 0
                    to: 65535
                    editable: true
                    value: startRegisterField.value + 10
                }
            }
        }
        
        onAccepted: {
            if (groupNameField.text.trim() === "") {
                return;
            }
            
            if (startRegisterField.value > endRegisterField.value) {
                return;
            }
            
            if (isHoldingGroup) {
                holdingRegisterGroups.append({
                    "name": groupNameField.text.trim(),
                    "startRegister": startRegisterField.value,
                    "endRegister": endRegisterField.value
                });
                updateHoldingRegisters();
            } else {
                inputRegisterGroups.append({
                    "name": groupNameField.text.trim(),
                    "startRegister": startRegisterField.value,
                    "endRegister": endRegisterField.value
                });
                updateInputRegisters();
            }
            
            // Reset fields
            groupNameField.text = "";
            startRegisterField.value = 0;
            endRegisterField.value = 10;
        }
    }
    
    SplitView {
        anchors.fill: parent
        orientation: Qt.Vertical
        
        // Main content area
        Rectangle {
            SplitView.fillHeight: true
            SplitView.minimumHeight: 200
            color: "transparent"
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5
                
                Text {
                    text: "Modbus Registers Editor"
                    font.bold: true
                    font.pixelSize: 18
                    Layout.alignment: Qt.AlignHCenter
                }
                
                // Group selection controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    Button {
                        text: "Add Group"
                        onClicked: {
                            registerTypeCombo.currentIndex = tabBar.currentIndex;
                            addGroupDialog.open();
                        }
                    }
                    
                    Button {
                        text: "Remove Group"
                        enabled: (tabBar.currentIndex === 0 && holdingRegisterGroups.count > 1) || 
                                 (tabBar.currentIndex === 1 && inputRegisterGroups.count > 1)
                        onClicked: {
                            if (tabBar.currentIndex === 0) {
                                holdingRegisterGroups.remove(selectedHoldingGroupIndex);
                                selectedHoldingGroupIndex = Math.min(selectedHoldingGroupIndex, holdingRegisterGroups.count - 1);
                                updateHoldingRegisters();
                            } else {
                                inputRegisterGroups.remove(selectedInputGroupIndex);
                                selectedInputGroupIndex = Math.min(selectedInputGroupIndex, inputRegisterGroups.count - 1);
                                updateInputRegisters();
                            }
                        }
                    }
                }
                
                // Tab bar for different register types
                TabBar {
                    id: tabBar
                    width: parent.width
                    Layout.fillWidth: true
                    
                    TabButton {
                        text: "Holding Registers"
                        width: implicitWidth
                    }
                    TabButton {
                        text: "Input Registers"
                        width: implicitWidth
                    }
                }
                
                StackLayout {
                    currentIndex: tabBar.currentIndex
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    // Holding Registers Tab
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 5
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Text {
                                    text: "Group: "
                                    font.bold: true
                                }
                                
                                ComboBox {
                                    id: holdingGroupCombo
                                    Layout.fillWidth: true
                                    model: holdingRegisterGroups
                                    textRole: "name"
                                    currentIndex: selectedHoldingGroupIndex
                                    onCurrentIndexChanged: {
                                        selectedHoldingGroupIndex = currentIndex;
                                        updateHoldingRegisters();
                                    }
                                }
                            }
                            
                            Text {
                                text: "Holding Registers: " + holdingStartRegister + " - " + holdingEndRegister
                                font.bold: true
                            }
                            
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                
                                ListView {
                                    id: holdingRegisterList
                                    model: Math.max(0, holdingEndRegister - holdingStartRegister + 1)
                                    delegate: registerDelegate
                                    spacing: 5
                                    
                                    property bool isInputRegister: false
                                    property int registerType: 4  // HoldingRegisters = 4
                                }
                            }
                        }
                    }
                    
                    // Input Registers Tab
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 5
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Text {
                                    text: "Group: "
                                    font.bold: true
                                }
                                
                                ComboBox {
                                    id: inputGroupCombo
                                    Layout.fillWidth: true
                                    model: inputRegisterGroups
                                    textRole: "name"
                                    currentIndex: selectedInputGroupIndex
                                    onCurrentIndexChanged: {
                                        selectedInputGroupIndex = currentIndex;
                                        updateInputRegisters();
                                    }
                                }
                            }
                            
                            Text {
                                text: "Input Registers: " + inputStartRegister + " - " + inputEndRegister
                                font.bold: true
                            }
                            
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                
                                ListView {
                                    id: inputRegisterList
                                    model: Math.max(0, inputEndRegister - inputStartRegister + 1)
                                    delegate: registerDelegate
                                    spacing: 5
                                    
                                    property bool isInputRegister: true
                                    property int registerType: 3  // InputRegisters = 3
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Log panel at bottom
        Rectangle {
            id: logPanel
            SplitView.preferredHeight: logPanelHeight
            SplitView.minimumHeight: 50
            color: "#222222"
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 5
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Console Log"
                        font.bold: true
                        color: "white"
                    }
                    
                    Item { Layout.fillWidth: true } // Spacer
                    
                    Button {
                        text: "Clear"
                        onClicked: logHandler.clearLog()
                        implicitHeight: 22
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    ListView {
                        id: logView
                        anchors.fill: parent
                        model: logHandler.logEntries
                        delegate: logDelegate
                        spacing: 1
                        
                        // Track whether auto-scroll is enabled
                        property bool autoScroll: true
                        
                        ScrollBar.vertical: ScrollBar {
                            id: verticalScrollBar
                            active: true
                            
                            // Detect scrollbar interactions
                            onPressedChanged: {
                                if (pressed) {
                                    // User pressed scrollbar - disable auto-scroll
                                    logView.autoScroll = false;
                                } else {
                                    // User released scrollbar - only re-enable auto-scroll if at bottom
                                    if (logView.atYEnd) {
                                        logView.autoScroll = true;
                                    }
                                }
                            }
                        }
                        
                        // Auto-scroll to bottom when new entries are added
                        onCountChanged: {
                            if (autoScroll || count <= 1) {
                                positionViewAtEnd();
                            }
                        }
                        
                        // Detect when the user starts interaction with the list
                        onMovementStarted: {
                            autoScroll = false;
                        }
                        
                        // When user stops interacting with list
                        onMovementEnded: {
                            // Only resume auto-scrolling if we're at the bottom
                            if (atYEnd) {
                                autoScroll = true;
                            }
                        }
                        
                        // When user flicks the list
                        onFlickStarted: {
                            autoScroll = false;
                        }
                        
                        // If user scrolls to bottom, re-enable auto-scrolling
                        onContentYChanged: {
                            if (atYEnd && !moving && !flicking) {
                                autoScroll = true;
                            }
                        }
                    }
                }  
            }
        }
    }
    
    // Console log delegate
    Component {
        id: logDelegate
        
        Rectangle {
            width: ListView.view.width
            height: logText.implicitHeight + 4
            color: "transparent"
            
            Text {
                id: logText
                anchors.fill: parent
                text: modelData
                color: {
                    if (modelData.includes("[CRITICAL]") || modelData.includes("[FATAL]")) 
                        return "red";
                    else if (modelData.includes("[WARNING]"))
                        return "yellow";
                    else if (modelData.includes("[DEBUG]"))
                        return "lightgreen";
                    else
                        return "white";
                }
                font.family: "Courier"
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }
    }
    
    // Common delegate for both register types
    Component {
        id: registerDelegate
        
        Rectangle {
            id: delegateRect
            width: ListView.view.width
            height: 60
            color: index % 2 === 0 ? "#e0f0e0" : "#d0e8d0"
            border.color: "#a0c0a0"
            border.width: 1
            radius: 4
            
            // Determine register address based on list type
            property bool isInput: ListView.view.isInputRegister
            property int regAddress: isInput ? 
                                   (inputStartRegister + index) : 
                                   (holdingStartRegister + index)
            
            // Get register type from ListView
            property int regType: ListView.view.registerType
            
            // Get value based on register type
            property int regValue: isInput ? 
                                  modbusDataStore.getInputRegister(regAddress) :
                                  modbusDataStore.getHoldingRegister(regAddress)
            
            // Force update of this component when data changes
            Connections {
                target: modbusDataStore
                function onDataChanged() {
                    delegateRect.regValue = Qt.binding(function() { 
                        return isInput ? 
                            modbusDataStore.getInputRegister(regAddress) :
                            modbusDataStore.getHoldingRegister(regAddress);
                    });
                }
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 2
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: isInput ? "Input " + regAddress : "Holding " + regAddress
                        font.bold: true
                        Layout.preferredWidth: 120
                    }
                    
                    TextField {
                        id: valueField
                        text: delegateRect.regValue.toString()
                        validator: IntValidator { bottom: 0; top: 65535 }
                        Layout.preferredWidth: 80
                        onEditingFinished: {
                            let value = parseInt(text);
                            if (!isNaN(value)) {
                                if (isInput) {
                                    modbusDataStore.setInputRegister(regAddress, value);
                                } else {
                                    modbusDataStore.setHoldingRegister(regAddress, value);
                                }
                            }
                        }
                        
                        // Update text field when regValue changes externally
                        Binding {
                            target: valueField
                            property: "text"
                            value: delegateRect.regValue.toString()
                        }
                    }
                    
                    Text {
                        id: hexText
                        Layout.preferredWidth: 100
                        text: "Hex: 0x" + delegateRect.regValue.toString(16).padStart(4, '0').toUpperCase()
                    }
                    
                    Text {
                        id: binaryText
                        Layout.fillWidth: true
                        text: "Binary: " + delegateRect.regValue.toString(2).padStart(16, '0')
                    }
                }
                
                // Bit editor
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    Repeater {
                        model: 16
                        
                        CheckBox {
                            property int bitPosition: 15-modelData
                            text: (bitPosition + 1)
                            // Use numeric register type (3 for InputRegisters, 4 for HoldingRegisters)
                            checked: modbusDataStore.getBit(regAddress, bitPosition, delegateRect.regType)
                            onToggled: {
                                // Use numeric register type
                                modbusDataStore.setBit(regAddress, bitPosition, checked, delegateRect.regType);
                            }
                            width: 35
                            
                            // Update checkbox when regValue changes externally
                            Connections {
                                target: modbusDataStore
                                function onDataChanged() {
                                    checked = Qt.binding(function() {
                                        // Use numeric register type
                                        return modbusDataStore.getBit(regAddress, bitPosition, delegateRect.regType);
                                    });
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Listen for data changes and update UI
    Connections {
        target: modbusDataStore
        function onDataChanged() {
            holdingRegisterList.forceLayout();
            inputRegisterList.forceLayout();
        }
    }
}
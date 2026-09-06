import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "sw.art.autostart"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    readonly property var barIdentity: hostWidget || root
    readonly property string backend: Quickshell.env("HOME") + "/.local/bin/omarchy-autostart-apps"

    property var apps: []
    property var catalog: []
    property bool picking: false
    property string query: ""
    property bool catalogLoaded: false
    property bool autostartOn: true

    readonly property string toggleHint: autostartOn ? "Turn autostart off" : "Turn autostart on"
    readonly property string heroStatusText: {
        if (!autostartOn)
            return "Off"
        if (picking)
            return "Pick an app"
        if (apps.length === 0)
            return "None yet"
        if (apps.length === 1)
            return "1 app"
        return apps.length + " apps"
    }

    readonly property var filteredCatalog: {
        var needle = query.trim().toLowerCase()
        var taken = {}
        for (var i = 0; i < apps.length; i++)
            taken[String(apps[i].id)] = true
        var out = []
        for (var j = 0; j < catalog.length; j++) {
            var item = catalog[j]
            var ident = String(item.id || "")
            if (taken[ident])
                continue
            if (!needle || String(item.name || "").toLowerCase().indexOf(needle) >= 0 || ident.toLowerCase().indexOf(needle) >= 0)
                out.push(item)
        }
        return out
    }

    function open() {
        picking = false
        query = ""
        root.controller.show()
        refreshList()
    }

    function openFromHotkey() {
        root.open()
    }

    function close() {
        picking = false
        query = ""
        root.controller.hide()
    }

    function toggle() {
        if (root.opened)
            root.close()
        else
            root.openFromHotkey()
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.barIdentity, direction)
        return false
    }

    function refreshList() {
        if (listProc.running)
            listProc.running = false
        listProc.running = true
    }

    function loadCatalog() {
        if (catalogProc.running)
            catalogProc.running = false
        catalogProc.running = true
    }

    function applyPayload(text) {
        var raw = String(text || "").trim()
        if (!raw)
            return
        try {
            var data = JSON.parse(raw)
            apps = Array.isArray(data.apps) ? data.apps : []
            autostartOn = data.enabled !== false
        } catch (e) {
        }
    }

    function runMutate(args) {
        mutateProc.command = [root.backend].concat(args)
        if (mutateProc.running)
            mutateProc.running = false
        mutateProc.running = true
    }

    function addApp(item) {
        if (!item || !item.id)
            return
        stopPicking()
        runMutate(["add", String(item.id), "1"])
    }

    function startPicking() {
        picking = true
        query = ""
        if (!catalogLoaded)
            loadCatalog()
        focusSearchField()
    }

    function stopPicking() {
        picking = false
        query = ""
        Qt.callLater(function() {
            if (keyCatcher)
                keyCatcher.forceActiveFocus()
        })
    }

    function focusSearchField() {
        Qt.callLater(function() {
            if (!root.picking || !searchField.visible)
                return
            searchField.forceActiveFocus()
            searchField.selectAll()
        })
    }

    function removeApp(item) {
        if (!item || !item.id)
            return
        runMutate(["remove", String(item.id)])
    }

    function cycleWorkspace(item, delta) {
        if (!item || !item.id)
            return
        var next = ((Number(item.workspace) || 1) - 1 + delta + 9) % 9 + 1
        runMutate(["workspace", String(item.id), String(next)])
    }

    function setAutostartOn(on) {
        autostartOn = on === true
        runMutate([autostartOn ? "enable" : "disable"])
    }

    Process {
        id: listProc
        command: [root.backend, "list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyPayload(text)
        }
    }

    Process {
        id: catalogProc
        command: [root.backend, "catalog"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(String(text || "").trim() || "{}")
                    root.catalog = Array.isArray(data.apps) ? data.apps : []
                    root.catalogLoaded = true
                } catch (e) {
                    root.catalog = []
                    root.catalogLoaded = true
                }
            }
        }
    }

    Process {
        id: mutateProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyPayload(text)
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/omarchy/autostart-apps.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refreshList()
    }

    Component.onCompleted: refreshList()

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(380))
        contentHeight: panel.fittedContentHeight(column.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            blocked: root.picking
            onCloseRequested: root.close()
            onTabRequested: function(direction) {
                root.switchPanel(direction)
            }

            Column {
                id: column
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Style.space(14)

                Item {
                    width: parent.width
                    implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroActions.implicitHeight)

                    Text {
                        id: heroIcon
                        text: "󰀻"
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.display
                        opacity: root.autostartOn ? 1.0 : 0.5
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        id: heroActions
                        spacing: Style.space(8)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: addButton
                            width: 28
                            height: 28
                            radius: Style.cornerRadius
                            anchors.verticalCenter: parent.verticalCenter
                            color: Style.hoverFillFor(root.bar.foreground, Color.accent)
                            Text {
                                anchors.centerIn: parent
                                text: root.picking ? "\u2715" : "+"
                                color: root.bar.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.body
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.picking)
                                        root.stopPicking()
                                    else
                                        root.startPicking()
                                }
                            }
                        }

                        ToggleSwitch {
                            id: powerSwitch
                            checked: root.autostartOn
                            foreground: root.bar.foreground
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: root.setAutostartOn(!root.autostartOn)

                            PanelToolTip {
                                visible: powerSwitch.containsMouse
                                text: root.toggleHint
                                fontFamily: root.bar.fontFamily
                            }
                        }
                    }

                    Column {
                        id: heroLabels
                        anchors.left: heroIcon.right
                        anchors.leftMargin: Style.space(14)
                        anchors.right: parent.right
                        anchors.rightMargin: heroActions.width + Style.space(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)

                        Text {
                            text: "Autostart"
                            color: root.bar.foreground
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.title
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: root.heroStatusText.toUpperCase()
                            color: Qt.darker(root.bar.foreground, 1.4)
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1.2
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Style.spacing.hairline
                    color: root.bar.foreground
                    opacity: 0.12
                }

                Column {
                    visible: root.picking
                    width: parent.width
                    spacing: Style.space(10)

                    TextField {
                        id: searchField
                        width: parent.width
                        placeholderText: "Search apps"
                        text: root.query
                        foreground: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.body
                        onTextChanged: root.query = text
                        onVisibleChanged: if (visible) root.focusSearchField()
                        Keys.onEscapePressed: root.stopPicking()
                    }

                    Text {
                        visible: !root.catalogLoaded
                        text: "Loading apps\u2026"
                        color: Qt.darker(root.bar.foreground, 1.4)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.body
                    }

                    Text {
                        visible: root.catalogLoaded && root.filteredCatalog.length === 0
                        text: "No matching apps"
                        color: Qt.darker(root.bar.foreground, 1.4)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.body
                    }

                    Repeater {
                        model: root.catalogLoaded ? root.filteredCatalog.slice(0, 8) : []
                        delegate: Item {
                            width: column.width
                            height: 34

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: root.bar.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.body
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addApp(modelData)
                            }
                        }
                    }
                }

                Column {
                    visible: !root.picking
                    width: parent.width
                    spacing: Style.space(8)

                    Text {
                        visible: root.apps.length === 0
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Add apps that should open at login. Click the workspace number to change it."
                        color: Qt.darker(root.bar.foreground, 1.4)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.body
                    }

                    Repeater {
                        model: root.apps
                        delegate: Item {
                            width: column.width
                            height: 36

                            Text {
                                anchors.left: parent.left
                                anchors.right: wsLabel.left
                                anchors.rightMargin: Style.space(10)
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: root.bar.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.body
                                elide: Text.ElideRight
                            }

                            Text {
                                id: wsLabel
                                anchors.right: wsChip.left
                                anchors.rightMargin: Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Workspace"
                                color: Qt.darker(root.bar.foreground, 1.4)
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.caption
                            }

                            Rectangle {
                                id: wsChip
                                width: 44
                                height: 26
                                radius: Style.cornerRadius
                                anchors.right: removeBtn.left
                                anchors.rightMargin: Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                color: Style.hoverFillFor(root.bar.foreground, Color.accent)
                                Text {
                                    anchors.centerIn: parent
                                    text: String(modelData.workspace)
                                    color: root.bar.foreground
                                    font.family: root.bar.fontFamily
                                    font.pixelSize: Style.font.body
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function(mouse) {
                                        root.cycleWorkspace(modelData, mouse.button === Qt.RightButton ? -1 : 1)
                                    }
                                }
                            }

                            Rectangle {
                                id: removeBtn
                                width: 26
                                height: 26
                                radius: Style.cornerRadius
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                color: "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u2715"
                                    color: Qt.darker(root.bar.foreground, 1.5)
                                    font.family: root.bar.fontFamily
                                    font.pixelSize: Style.font.caption
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.removeApp(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

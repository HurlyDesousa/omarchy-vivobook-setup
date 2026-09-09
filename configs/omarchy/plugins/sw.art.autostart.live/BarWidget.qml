import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "sw.art.autostart"

    property string pendingPanelAction: ""
    property bool fileAutostartOn: true
    readonly property string backend: Quickshell.env("HOME") + "/.local/bin/omarchy-autostart-apps"

    function injectPanel() {
        var target = panelLoader.item
        if (!target)
            return
        if ("bar" in target)
            target.bar = root.bar
        if ("settings" in target)
            target.settings = root.settings
        if ("anchorItem" in target)
            target.anchorItem = button
        if ("hostWidget" in target)
            target.hostWidget = root
    }

    function runPanelAction(action) {
        if (!action)
            return
        if (!panelLoader.item) {
            root.pendingPanelAction = action
            panelLoader.active = true
            return
        }
        var item = panelLoader.item
        if (action === "toggle" && item.toggle) item.toggle()
        else if (action === "open" && item.openFromHotkey) item.openFromHotkey()
        else if (action === "close" && item.close) item.close()
        else if (action === "closeForPopoutSwitch" && item.closeForPopoutSwitch)
            item.closeForPopoutSwitch()
    }

    function togglePanel() {
        root.runPanelAction("toggle")
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root, direction)
        return false
    }

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool autostartOn: panelLoader.item ? panelLoader.item.autostartOn !== false : root.fileAutostartOn

    function syncEnabledFromText(raw) {
        var text = String(raw || "").trim()
        if (!text)
            return
        try {
            var data = JSON.parse(text)
            root.fileAutostartOn = data.enabled !== false
        } catch (e) {
        }
    }

    function toggleAutostart() {
        if (panelLoader.item && panelLoader.item.setAutostartOn) {
            panelLoader.item.setAutostartOn(!root.autostartOn)
            return
        }
        toggleProc.command = [root.backend, root.autostartOn ? "disable" : "enable"]
        if (toggleProc.running)
            toggleProc.running = false
        toggleProc.running = true
    }

    function open() {
        root.runPanelAction("open")
    }

    function close() {
        if (panelLoader.item && panelLoader.item.close)
            panelLoader.item.close()
    }

    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    function closeForPopoutSwitch() {
        if (panelLoader.item)
            panelLoader.item.closeForPopoutSwitch()
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()
    onSettingsChanged: injectPanel()

    FileView {
        path: Quickshell.env("HOME") + "/.config/omarchy/autostart-apps.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.syncEnabledFromText(text())
        onFileChanged: reload()
    }

    Process {
        id: toggleProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.syncEnabledFromText(text)
        }
    }

    Loader {
        id: panelLoader
        active: false
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            var action = root.pendingPanelAction
            root.pendingPanelAction = ""
            if (action)
                Qt.callLater(function() { root.runPanelAction(action) })
        }
    }

    BarIconButton {
        id: button
        bar: root.bar
        text: "󰀻"
        dimmed: !root.autostartOn
        tooltipText: root.autostartOn ? "Autostart" : "Autostart off"
        onPressed: function(b) {
            if (b === Qt.RightButton)
                root.toggleAutostart()
            else
                root.togglePanel()
        }
    }
}

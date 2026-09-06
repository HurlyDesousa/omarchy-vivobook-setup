import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "sw.art.autostart"

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

    function togglePanel() {
        if (panelLoader.item && panelLoader.item.toggle)
            panelLoader.item.toggle()
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root, direction)
        return false
    }

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool autostartOn: panelLoader.item ? panelLoader.item.autostartOn !== false : true

    function toggleAutostart() {
        if (panelLoader.item && panelLoader.item.setAutostartOn)
            panelLoader.item.setAutostartOn(!root.autostartOn)
    }

    function open() {
        if (panelLoader.item && panelLoader.item.openFromHotkey)
            panelLoader.item.openFromHotkey()
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

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
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

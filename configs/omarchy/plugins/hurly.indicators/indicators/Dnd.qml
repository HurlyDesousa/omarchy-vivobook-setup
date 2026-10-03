import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../Host.js" as Host

BarIndicator {
  id: root

  readonly property var notificationService: Host.serviceFromBar(bar, ["omarchy.notifications"])
  property bool fileDnd: false
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : fileDnd

  active: dnd
  activeText: "󰂛"
  inactiveText: "󰂛"
  activeTooltipText: "Allow Notifications"
  inactiveTooltipText: "Silence Notifications"

  function applySettings(raw) {
    try {
      var d = JSON.parse(String(raw || "{}"))
      if (d && typeof d.dnd === "boolean") root.fileDnd = d.dnd
    } catch (e) {}
  }

  onPressed: function() {
    if (root.notificationService)
      root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
    else
      Quickshell.execDetached(Host.ipc(["notifications", "toggleDnd"]))
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applySettings(text())
    onFileChanged: reload()
  }
}

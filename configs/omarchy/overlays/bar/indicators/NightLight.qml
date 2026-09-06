import QtQuick
import qs.Ui

BarIndicator {
  id: root

  readonly property var nightlightService: bar?.shell?.firstPartyServiceFor("omarchy.nightlight")

  property bool autoProbeRunning: false
  property bool autoEnabled: false

  active: nightlightService ? nightlightService.enabled : false
  activeText: "󰔎"
  inactiveText: "󰔎"
  activeTooltipText: autoEnabled ? "Day light (auto on)" : "Day light"
  inactiveTooltipText: autoEnabled ? "Night light (auto on)" : "Night light"

  function refreshAutoState() {
    if (autoProbeRunning) return
    autoProbe.running = true
    autoProbeRunning = true
  }

  function toggle() {
    if (root.nightlightService) root.nightlightService.setNightlight(!root.active)
  }

  function toggleAuto() {
    autoToggleProcess.running = true
  }

  onPressed: function(mouse) {
    if (mouse.button === Qt.MiddleButton) {
      root.toggleAuto()
      return
    }
    root.toggle()
  }

  Component.onCompleted: refreshAutoState()

  Process {
    id: autoProbe
    command: ["bash", "-lc", "grep -qx on ~/.local/state/omarchy/nightlight/auto 2>/dev/null && echo on || echo off"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.autoEnabled = String(text).trim() === "on"
        root.autoProbeRunning = false
      }
    }
    onExited: { root.autoProbeRunning = false }
  }

  Process {
    id: autoToggleProcess
    command: ["omarchy-vivobook-nightlight-auto", "toggle"]
    onExited: root.refreshAutoState()
  }
}

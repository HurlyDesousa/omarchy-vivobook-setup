import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Stock Omarchy NightLight indicator with Vivobook right-click auto panel.
// Left-click path is unchanged from upstream; right-click is a separate overlay.
BarIndicator {
  id: root

  readonly property var nightlightService: bar?.shell?.firstPartyServiceFor("omarchy.nightlight")

  property bool autoEnabled: false
  property string statusText: ""
  property bool optionsOpen: false
  readonly property bool popoutSwitchClosing: false

  active: nightlightService ? nightlightService.enabled : false
  activeText: "󰔎"
  inactiveText: "󰔎"
  activeTooltipText: "Day Light"
  inactiveTooltipText: "Night Light"

  function toggle() {
    if (root.nightlightService) root.nightlightService.setNightlight(!root.active)
  }

  // Stock Omarchy: left-click (and any non-right press the bar routes here) toggles night light.
  onPressed: function() { root.toggle() }

  function parseStatus(raw) {
    var auto = "off"
    var rise = ""
    var sunset = ""
    String(raw).trim().split(/\s+/).forEach(function(part) {
      var kv = part.split("=")
      if (kv.length !== 2) return
      if (kv[0] === "auto") auto = kv[1]
      if (kv[0] === "sunrise") rise = kv[1]
      if (kv[0] === "sunset") sunset = kv[1]
    })
    root.autoEnabled = auto === "on"
    if (auto === "on" && rise && sunset)
      root.statusText = "Sunrise " + rise + " · Sunset " + sunset
    else
      root.statusText = "Auto off"
  }

  function refreshAutoState() {
    if (statusProbe.running) return
    statusProbe.running = true
  }

  function setAuto(enabled) {
    autoSetProcess.command = ["omarchy-vivobook-nightlight-auto", enabled ? "on" : "off"]
    if (!autoSetProcess.running) autoSetProcess.running = true
  }

  function openOptions() {
    refreshAutoState()
    optionsOpen = true
  }

  function closeOptions() {
    optionsOpen = false
  }

  function close() {
    closeOptions()
  }

  function closeForPopoutSwitch() {
    closeOptions()
  }

  Component.onCompleted: refreshAutoState()

  // Right-click only — propagate left button to stock onPressed below.
  MouseArea {
    anchors.fill: parent
    z: 1
    acceptedButtons: Qt.RightButton
    propagateComposedEvents: true
    onPressed: function(mouse) {
      if (mouse.button !== Qt.RightButton) mouse.accepted = false
    }
    onClicked: {
      if (root.optionsOpen) root.closeOptions()
      else root.openOptions()
    }
  }

  KeyboardPanel {
    id: optionsPanel
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.optionsOpen
    contentWidth: optionsPanel.fittedContentWidth(Style.space(300))
    contentHeight: optionsPanel.fittedContentHeight(optionsColumn.implicitHeight)

    Column {
      id: optionsColumn
      width: parent.width
      spacing: Style.space(10)

      Toggle {
        id: autoToggle
        width: parent.width
        label: "Auto"
        description: "Berlin sunrise–sunset"
        checked: root.autoEnabled
        onClicked: root.setAuto(!root.autoEnabled)
      }

      Text {
        width: parent.width
        text: root.statusText
        visible: root.statusText !== ""
        color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }

  Process {
    id: statusProbe
    command: ["omarchy-vivobook-nightlight-auto", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.autoEnabled = false
        root.statusText = "Auto off"
      }
    }
  }

  Process {
    id: autoSetProcess
    onExited: root.refreshAutoState()
  }
}

import QtQuick
import Quickshell
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
    property string sunriseText: ""
    property string sunsetText: ""
    property int warmth: 50
    property int hyprTemp: -1
    property bool optionsOpen: false
    readonly property bool isPrimary: indicatorBlock === "inactive"
    readonly property bool popoutSwitchClosing: false
    readonly property string autoBin: Quickshell.env("HOME") + "/.local/bin/omarchy-vivobook-nightlight-auto"
    readonly property int menuWidth: Math.max(Style.space(220), autoRow.implicitWidth, statusLabel.visible ? statusLabel.implicitWidth : 0)
    readonly property bool filterOn: {
      if (root.nightlightService && root.nightlightService.stateLoaded)
        return root.nightlightService.enabled === true
      return root.hyprTemp >= 1000 && root.hyprTemp < 6000
    }

    // hyprctl prints IPC errors on stdout ("Couldn't connect to /run/user/1000/...").
    // Taking the first digit run from that string yields 1000 and leaves the icon on.
    function parseHyprTemp(raw) {
        var s = String(raw).trim()
        if (!s || /couldn|connect|\/run\/user\//i.test(s))
            return -1
        var m = s.match(/^([0-9]+)\s*K?$/i)
        if (!m)
            return -1
        var n = Number(m[1])
        if (n < 1000 || n > 20000)
            return -1
        return n
    }

  active: root.filterOn
  activeText: "󰔎"
  inactiveText: "󰔎"
  activeTooltipText: "Day Light"
  inactiveTooltipText: "Night Light"

    function nightKelvin() {
        return Math.round(5500 - Math.max(0, Math.min(100, root.warmth)) * 30)
    }

    function readHyprTemp() {
        if (!tempProbe.running)
            tempProbe.running = true
    }

    function publishTemp(temp) {
        root.hyprTemp = temp
        if (temp >= 1000 && root.nightlightService) {
            root.nightlightService.temperature = temp
            root.nightlightService.stateLoaded = true
        }
    }

    onIsPrimaryChanged: {
      if (root.isPrimary)
        root.readHyprTemp()
    }

    function toggle() {
        var turningOn = !root.filterOn
        if (root.nightlightService) {
            root.nightlightService.noteManualOverride(turningOn)
            root.nightlightService.applyTemperature(turningOn ? root.nightKelvin() : 6500)
        } else {
            Quickshell.execDetached([root.autoBin, turningOn ? "now-on" : "now-off"])
        }
        root.readHyprTemp()
    }

  // Stock Omarchy: left-click (and any non-right press the bar routes here) toggles night light.
  onPressed: function() { root.toggle() }

  function parseStatus(raw) {
        var auto = "off"
        var rise = ""
        var sunset = ""
        var amount = root.warmth
        String(raw).trim().split(/\s+/).forEach(function(part) {
            var kv = part.split("=")
            if (kv.length !== 2) return
            if (kv[0] === "auto") auto = kv[1]
            if (kv[0] === "sunrise") rise = kv[1]
            if (kv[0] === "sunset") sunset = kv[1]
            if (kv[0] === "amount") amount = Number(kv[1])
        })
        root.autoEnabled = auto === "on"
        if (rise)
            root.sunriseText = rise
        if (sunset)
            root.sunsetText = sunset
        if (!warmthSlider.dragging && !isNaN(amount))
            root.warmth = Math.max(0, Math.min(100, Math.round(amount)))
        root.statusText = root.autoStatusText()
  }

  function refreshAutoState() {
    if (statusProbe.running) return
    statusProbe.running = true
  }

    function autoStatusText() {
        if (root.autoEnabled && root.sunriseText && root.sunsetText)
            return "Sunrise " + root.sunriseText + " · Sunset " + root.sunsetText
        if (root.autoEnabled)
            return "Auto on"
        return "Auto off"
    }

    function setAuto(enabled) {
        root.autoEnabled = enabled
        root.statusText = root.autoStatusText()
        autoSetProcess.command = ["omarchy-vivobook-nightlight-auto", enabled ? "on" : "off"]
        if (autoSetProcess.running)
            autoSetProcess.running = false
        autoSetProcess.running = true
    }

    function queueWarmth(value) {
        root.warmth = Math.max(0, Math.min(100, Math.round(value)))
        warmthDebounce.restart()
    }

    function commitWarmth() {
        warmthDebounce.stop()
        warmthSetProcess.command = ["omarchy-vivobook-nightlight-auto", "amount", String(root.warmth)]
        if (warmthSetProcess.running)
            warmthSetProcess.running = false
        warmthSetProcess.running = true
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
    contentWidth: optionsPanel.fittedContentWidth(root.menuWidth + Style.spacing.popupPadding * 2)
    contentHeight: optionsPanel.fittedContentHeight(optionsColumn.implicitHeight)

    Column {
      id: optionsColumn
      width: root.menuWidth
      spacing: Style.space(10)

      Row {
        id: autoRow
        spacing: Style.space(12)

        Text {
          text: "Auto"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }

        ToggleSwitch {
          checked: root.autoEnabled
          foreground: root.bar ? root.bar.foreground : Color.foreground
          anchors.verticalCenter: parent.verticalCenter
          onToggled: root.setAuto(!root.autoEnabled)
        }
      }

      Text {
        id: statusLabel
        visible: root.statusText !== ""
        width: parent.width
        text: root.statusText
        color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }

      Item {
        width: parent.width
        implicitHeight: Math.max(amountLabel.implicitHeight, amountValue.implicitHeight)

        Text {
          id: amountLabel
          text: "Amount"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          id: amountValue
          text: Math.round(warmthSlider.dragging ? warmthSlider.liveValue : root.warmth) + "%"
          color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      PanelSlider {
        id: warmthSlider
        bar: root.bar
        width: parent.width
        minimum: 0
        maximum: 100
        step: 5
        integer: true
        value: root.warmth
        onMoved: function(v) { root.queueWarmth(v) }
        onReleased: function(v) {
          root.warmth = Math.max(0, Math.min(100, Math.round(v)))
          root.commitWarmth()
        }
      }
    }
  }

  Process {
    id: tempProbe
    command: ["hyprctl", "hyprsunset", "temperature"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var temp = root.parseHyprTemp(text)
        if (temp >= 1000)
          root.publishTemp(temp)
        else
          root.hyprTemp = -1
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.hyprTemp = -1
    }
  }

  // Auto sunrise/sunset updates hyprsunset without notifying the service.
  // One copy probes; the rest bind to the shared nightlight service.
  Timer {
    interval: 5000
    running: root.isPrimary
    repeat: true
    onTriggered: root.readHyprTemp()
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

  Process {
    id: warmthSetProcess
  }

  Timer {
    id: warmthDebounce
    interval: 80
    repeat: false
    onTriggered: root.commitWarmth()
  }
}

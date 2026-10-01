import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "omarchy.power"
  ipcTarget: "omarchy.power"
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the togglePercentage method below.
  manageIpc: false
  property var batteryInfo: ({})
  property var systemInfo: ({})
  property var profiles: []
  property string activeProfile: ""
  property int profileIndex: 0
  property bool cursorActive: false
  property real liveWatts: 0
  property real kernelMicrowatts: 0
  property real helperLiveMicrowatts: 0
  property int cordMicroamps: 0
  property int cordMicrovolts: 0
  property bool cordPlugged: false
  property string batteryStatus: ""
  property var energyLog: []
  readonly property string pluginDir: {
    var s = String(Qt.resolvedUrl("."))
    if (s.indexOf("file://") === 0)
      s = decodeURIComponent(s.slice(7))
    if (s.length > 1 && s.charAt(s.length - 1) === "/")
      s = s.slice(0, s.length - 1)
    return s
  }
  readonly property bool showPercentage: setting("showPercentage", false) === true
  // With the percentage shown the button paints a text block wider than an
  // icon, so the open-panel mark takes the painted width instead of the
  // icon-sized fraction of the slot the fallback assumes.
  readonly property real openPanelIndicatorWidth: showPercentage && !button.vertical ? button.glyphPaintedWidth : 0
  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }

  function upowerStates() {
    return {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    }
  }

  function selectProfileByDelta(deltaX, deltaY) {
    profileIndex = Model.selectProfileGridIndex(profileIndex, deltaX, deltaY, profiles, 2)
  }

  function activateSelectedProfile() {
    if (profileIndex < 0 || profileIndex >= profiles.length) return
    setProfile(profiles[profileIndex])
  }

  function batteryIcon() {
    var device = UPower.displayDevice
    return Model.batteryIcon(device, root.discharging, upowerStates())
  }

  function modeLabel() {
    var device = UPower.displayDevice
    return Model.modeLabel(device, root.discharging, upowerStates())
  }

  function profileIcon(name) {
    return Model.profileIcon(name)
  }

  readonly property string sysBatteryDir: {
    var device = UPower.displayDevice
    var name = device && device.nativePath ? String(device.nativePath) : "qcom-battmgr-bat"
    var parts = name.split("/")
    name = parts[parts.length - 1]
    if (!name) name = "qcom-battmgr-bat"
    return "/sys/class/power_supply/" + name
  }

  readonly property string powerDrawText: {
    var text = root.liveWatts.toFixed(1) + "W"
    if (root.discharging) return "↓ " + text
    if (root.charging) return "↑ " + text
    return text
  }

  readonly property bool showTimeRow: root.chargeThresholdActive || root.discharging || !root.batteryFull

  function parseSysInt(raw) {
    var n = parseInt(String(raw || "").trim(), 10)
    return isFinite(n) ? n : 0
  }

  function refreshLiveWatts() {
    var watts = Math.abs(root.helperLiveMicrowatts) / 1000000
    if (watts < 0.05) {
      var battery = Math.abs(root.kernelMicrowatts) / 1000000
      var device = UPower.displayDevice
      var upower = device ? Math.abs(Number(device.changeRate || 0)) : 0
      var derived = 0
      var log = root.energyLog
      if (log.length >= 2) {
        var dt = (log[log.length - 1].t - log[0].t) / 1000
        if (dt >= 2.5) derived = Math.abs(log[0].e - log[log.length - 1].e) * 3.6 / dt
      }
      if (battery < 0.08) battery = Math.max(upower, derived)
      watts = battery
    }
    if (!isFinite(watts) || watts < 0) watts = 0
    root.liveWatts = watts
  }

  function ingestEnergy(uwh) {
    var now = Date.now()
    var next = []
    var log = root.energyLog
    for (var i = 0; i < log.length; i++) {
      if (now - log[i].t <= 25000) next.push(log[i])
    }
    var last = next.length ? next[next.length - 1] : null
    if (!last || last.e !== uwh || now - last.t >= 400) next.push({ t: now, e: uwh })
    root.energyLog = next
    root.refreshLiveWatts()
  }

  readonly property bool fullyCharged: {
    if (root.discharging) return false
    var device = UPower.displayDevice
    return device && device.isPresent && device.state === UPowerDeviceState.FullyCharged && !root.chargeThresholdActive
  }
  readonly property bool discharging: {
    var device = UPower.displayDevice
    if (root.batteryStatus === "Discharging") return true
    if (root.cordPlugged) return false
    return !!(device && device.isPresent && UPower.onBattery)
  }
  readonly property bool onCord: root.cordPlugged && root.batteryStatus !== "Discharging"
  readonly property bool chargeThresholdActive: {
    var device = UPower.displayDevice
    return Model.chargeThresholdActive(device, root.discharging, upowerStates())
  }
  readonly property bool batteryFull: fullyCharged || (!root.discharging && batteryFraction >= 1)
  readonly property bool batteryFlowIdle: !root.discharging && (root.batteryFull || root.chargeThresholdActive)

  // 0..1 charge level, used by the visual progress bar.
  readonly property real batteryFraction: {
    var d = UPower.displayDevice
    return Model.batteryFraction(d)
  }

  readonly property string batteryPercentLabel: {
    if (!root.batteryPresent) return "—"
    var n = Math.round(root.batteryFraction * 100)
    if (!isFinite(n)) return root.batteryInfo.percentage || "—"
    return n + "%"
  }

  readonly property bool charging: root.onCord && !root.discharging && !root.batteryFlowIdle

  function formatDuration(seconds) {
    var s = Number(seconds)
    if (!isFinite(s) || s < 45) return ""
    var totalMin = Math.round(s / 60)
    if (totalMin < 1) return ""
    var hours = Math.floor(totalMin / 60)
    var minutes = totalMin % 60
    if (hours > 0 && minutes > 0) return hours + "h " + minutes + "m"
    if (hours > 0) return hours + "h"
    return minutes + "m"
  }

  readonly property string remainingTimeText: {
    if (root.chargeThresholdActive && !root.discharging)
      return root.batteryInfo.threshold || "-"
    if (root.batteryFlowIdle)
      return "-"

    var fromScript = String(root.batteryInfo.time || "").trim()
    if (fromScript && fromScript !== "-" && fromScript !== "—")
      return fromScript

    var device = UPower.displayDevice
    var watts = root.liveWatts
    var energy = device ? Number(device.energy) : 0
    if (!(energy > 0.5) && root.energyLog.length)
      energy = root.energyLog[root.energyLog.length - 1].e / 1000000

    if (root.discharging) {
      var empty = device ? Number(device.timeToEmpty) : 0
      var text = root.formatDuration(empty)
      if (text) return text
      if (energy > 0.5 && watts >= 0.4)
        return root.formatDuration(energy / watts * 3600)
      return "—"
    }

    var full = device ? Number(device.timeToFull) : 0
    text = root.formatDuration(full)
    if (text) return text
    var capacity = device ? Number(device.energyCapacity) : 0
    var need = capacity - energy
    if (need > 0.2 && watts >= 0.4)
      return root.formatDuration(need / watts * 3600)
    return "—"
  }

  readonly property color batteryFillColor: {
    return root.bar ? root.bar.foreground : Color.foreground
  }

  // Cute agent-flavored phrases shown in the hero status line, rotated on a
  // timer so the panel feels alive when current is flowing (either direction).
  readonly property var chargingPhrases: [
    "Pumping power",
    "Injecting electrons",
    "Pouring juice",
    "Amassing watts",
    "Hoarding joules",
    "Sucking volts",
    "Topping reserves",
    "Soaking amps",
    "Inhaling kilowatts"
  ]
  readonly property var onBatteryPhrases: [
    "Slurping power",
    "Spending joules",
    "Draining watts",
    "Burning electrons",
    "Sipping juice",
    "Spending coulombs",
    "Bleeding amps",
    "Guzzling volts",
    "Munching reserves"
  ]
  property int phraseIndex: 0

  // Whichever list is "active" given the current power state.
  readonly property var activePhrases: {
    if (fullyCharged) return []
    if (charging) return chargingPhrases
    if (discharging) return onBatteryPhrases
    return []
  }
  readonly property bool rotatingPhrases: activePhrases.length > 0

  readonly property string heroStatusText: {
    if (fullyCharged) return "Fully charged"
    if (rotatingPhrases) return activePhrases[phraseIndex % activePhrases.length]
    return modeLabel()
  }

  function refresh() {
    if (!batteryPresent) return

    if (!batteryProc.running) batteryProc.running = true
    if (!profilesProc.running) profilesProc.running = true
    if (!systemProc.running) systemProc.running = true
  }

  function updateKeyValue(raw, targetName) {
    var next = Model.parseKeyValue(raw)
    // Keep last known good data if a refresh briefly returns nothing — happens
    // around AC plug/unplug events. Avoids the section collapsing mid-transition.
    if (Object.keys(next).length === 0) return
    if (targetName === "battery") batteryInfo = next
    else systemInfo = next
  }

  function updateProfiles(raw) {
    var parsed = Model.parseProfiles(raw, profileIndex)
    // Same guard as battery: preserve the last known profile list across
    // transient empty payloads so the buttons don't blink out.
    if (parsed.profiles.length === 0) return
    profiles = parsed.profiles
    activeProfile = parsed.activeProfile
    profileIndex = parsed.profileIndex
    if (opened && !cursorActive) {
      var idx = profiles.indexOf(activeProfile)
      if (idx >= 0) profileIndex = idx
    }
  }

  function setProfile(profile) {
    if (!profile || actionProc.running) return
    actionProc.command = ["omarchy-powerprofiles-set", root.discharging ? "battery" : "ac", profile]
    actionProc.running = true
  }

  function togglePercentage() {
    root.settings = Object.assign({}, root.settings, { showPercentage: !root.showPercentage })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  IpcHandler {
    target: "omarchy.power"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function togglePercentage() { root.togglePercentage() }
  }

  onOpenedChanged: {
    if (opened) {
      if (!batteryPresent) {
        close()
        return
      }

      refresh()
      var idx = profiles.indexOf(activeProfile)
      profileIndex = idx >= 0 ? idx : 0
      cursorActive = false
    }
  }

  onBatteryPresentChanged: if (!batteryPresent) close()

  visible: batteryPresent
  implicitWidth: batteryPresent ? button.implicitWidth : 0
  implicitHeight: batteryPresent ? button.implicitHeight : 0

  Process {
    id: batteryProc
    command: [Quickshell.env("HOME") + "/.local/lib/omarchy-vivobook/omarchy-battery-status", "--shell"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "battery") }
  }

  Process {
    id: profilesProc
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateProfiles(text) }
  }

  Process {
    id: systemProc
    command: ["omarchy-system-stats"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "system") }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: root.refresh() }

  Process {
    id: drawProc
    command: [root.pluginDir + "/read-draw"]
    stdout: SplitParser {
      onRead: function(line) {
        var parts = String(line).trim().split(/\s+/)
        if (parts.length < 2) return
        var key = parts[0]
        if (key === "battery_status") {
          root.batteryStatus = parts.slice(1).join(" ")
          root.refreshLiveWatts()
          return
        }
        var value = parseInt(parts[1], 10)
        if (!isFinite(value)) return
        if (key === "live_uw") {
          root.helperLiveMicrowatts = value
          root.refreshLiveWatts()
        } else if (key === "battery_uw") root.kernelMicrowatts = value
        else if (key === "battery_uwh") root.ingestEnergy(value)
        else if (key === "cord_ua") root.cordMicroamps = value
        else if (key === "cord_online") root.cordPlugged = value === 1
        else if (key === "cord_uv") root.cordMicrovolts = value
      }
    }
  }

  Connections {
    target: UPower.displayDevice
    function onChangeRateChanged() { root.refreshLiveWatts() }
    function onEnergyChanged() {
      var device = UPower.displayDevice
      if (device) root.ingestEnergy(Math.round(Number(device.energy) * 1000000))
    }
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() { root.refreshLiveWatts() }
  }

  Timer {
    interval: 1500
    running: root.batteryPresent
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!drawProc.running) drawProc.running = true
  }

  // Rotate the status phrase while the panel is open and we're in a
  // rotating state (charging or on battery). The text swap is wrapped in a
  // fade so the changeover reads as one organism rather than a hard cut.
  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.rotatingPhrases
    repeat: true
    triggeredOnStart: false
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 0.0; duration: 180; easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: {
        var n = root.activePhrases.length
        if (n > 0) root.phraseIndex = (root.phraseIndex + 1) % n
      }
    }
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 1.0; duration: 260; easing.type: Easing.InQuad
    }
  }

  // If we leave a rotating state mid-swap, halt the animation and snap back
  // to full opacity so "FULLY CHARGED" is legible immediately rather than
  // appearing dimmed.
  Connections {
    target: root
    function onRotatingPhrasesChanged() {
      if (!root.rotatingPhrases) {
        phraseSwap.stop()
        heroStatus.opacity = 1.0
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showPercentage && !vertical
      ? Math.round(root.batteryFraction * 100) + "% " + root.batteryIcon()
      : root.batteryIcon()
    slotSize: Style.bar.iconSlot * (root.showPercentage && !vertical ? 2 : 1)
    tooltipText: ""
    onPressed: function(b) {
      if (!root.batteryPresent) return
      if (b === Qt.RightButton) root.togglePercentage()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.batteryPresent
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.selectProfileByDelta(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateSelectedProfile()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: battery icon · title/status · percentage ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.batteryIcon()
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Battery"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              id: heroStatus
              textFormat: Text.PlainText
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

          Text {
            id: heroPercent
            textFormat: Text.PlainText
            text: root.batteryPercentLabel
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }
        }

        // ---------- Battery progress bar ----------
        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: barTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
          }

          Rectangle {
            id: barFill
            anchors.left: barTrack.left
            anchors.verticalCenter: barTrack.verticalCenter
            height: barTrack.height
            radius: barTrack.radius
            color: root.batteryFillColor
            width: Math.max(barTrack.height, barTrack.width * root.batteryFraction)

            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }

            // Subtle pulse while charging — visible signal that energy is flowing in.
            SequentialAnimation on opacity {
              running: root.charging && !root.fullyCharged && root.opened
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }
          }
        }

        // ---------- Stats ----------
        // Visibility is intentionally only gated by "we've ever loaded data" so
        // the section never collapses mid-transition. fullyCharged is *not* part
        // of the condition: UPower briefly reports FullyCharged on plug-in when
        // the battery sits above the charge-control start threshold, and we
        // refuse to flicker the whole panel for that ~1s window.
        Row {
          visible: root.batteryPresent
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Battery size"; value: root.batteryInfo.size || "" }
            InfoPair { label: "Charge cycles"; value: root.batteryInfo.cycles || "—" }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair {
              visible: root.showTimeRow
              label: root.chargeThresholdActive && !root.discharging ? "Charge limit" : (root.discharging ? "Time left" : "Time to full")
              value: root.remainingTimeText
            }
            InfoPair {
              label: root.onCord ? "Cord draw" : "Battery draw"
              value: root.powerDrawText
            }
          }
        }

        // ---------- Power profile picker ----------
        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "POWER PROFILE"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Column {
            id: profileGrid
            width: parent.width
            spacing: Style.space(6)

            readonly property var ordered: root.profiles
            readonly property int columns: 2

            Repeater {
              model: profileGrid.ordered.length > 0
                ? Math.ceil(profileGrid.ordered.length / profileGrid.columns)
                : 0

              Row {
                required property int index
                width: profileGrid.width
                spacing: Style.space(6)

                readonly property real cellWidth: (width - spacing * (profileGrid.columns - 1)) / profileGrid.columns

                Repeater {
                  model: profileGrid.columns

                  Button {
                    required property int index
                    property int gridIndex: parent.index * profileGrid.columns + index
                    property string profileName: gridIndex < profileGrid.ordered.length
                      ? String(profileGrid.ordered[gridIndex])
                      : ""

                    visible: profileName !== ""
                    width: parent.cellWidth
                    iconText: root.profileIcon(profileName)
                    iconSize: Style.font.title
                    text: Model.profileLabel(profileName)
                    fontSize: Style.font.bodySmall
                    foreground: root.bar.foreground
                    fontFamily: root.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                    bordered: true
                    active: root.activeProfile === profileName
                    hasCursor: root.cursorActive && root.profileIndex === gridIndex
                    onClicked: root.setProfile(profileName)
                    onHovered: function(h) {
                      if (h && profileName) {
                        root.cursorActive = true
                        root.profileIndex = gridIndex
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}

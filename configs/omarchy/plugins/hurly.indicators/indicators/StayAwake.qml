import QtQuick
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  readonly property var idleService: {
    var sh = bar && bar.shell ? bar.shell : null
    if (!sh) return null
    var services = sh._services || {}
    var resolved = "omarchy.idle"
    if (sh.pluginRegistry && typeof sh.pluginRegistry.resolveEnabledId === "function")
      resolved = sh.pluginRegistry.resolveEnabledId("omarchy.idle") || resolved
    return services[resolved] || services["hurly.idle"] || services["omarchy.idle"] || null
  }

  property bool optionsOpen: false
  readonly property bool popoutSwitchClosing: false
  property int powerMinutes: 15
  property int batteryMinutes: 5
  readonly property int menuWidth: Style.space(220)
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  active: idleService ? idleService.stayAwake : false
  activeText: "󰅶"
  inactiveText: "󰅶"
  activeTooltipText: "Stay awake is on — click to allow lock"
  inactiveTooltipText: "Idle timer is on — click to stay awake"

  function minutesFromSeconds(seconds, fallback) {
    var n = Number(seconds)
    if (!isFinite(n) || n < 0) return fallback
    return Math.max(0, Math.round(n / 60))
  }

  function syncFromService() {
    if (!root.idleService) return
    root.powerMinutes = minutesFromSeconds(root.idleService.screensaverOnAcSeconds, 15)
    root.batteryMinutes = minutesFromSeconds(root.idleService.screensaverOnBatterySeconds, 5)
  }

  function commitMinutes(kind, minutes) {
    var mins = Math.max(1, Math.min(240, Math.round(Number(minutes) || 0)))
    var sec = mins * 60
    if (kind === "battery") root.batteryMinutes = mins
    else root.powerMinutes = mins

    var sh = bar && bar.shell ? bar.shell : null
    if (!sh || typeof sh.mutateShellConfig !== "function") return
    sh.mutateShellConfig(function(config) {
      if (!config.idle || typeof config.idle !== "object")
        config.idle = { lock: 300, screensaver: 900, screensaverBattery: 300, dim: 0 }
      if (kind === "battery") config.idle.screensaverBattery = sec
      else config.idle.screensaver = sec
    })
  }

  function toggle() {
    if (root.idleService) root.idleService.setIdleEnabled(root.active)
  }

  function openOptions() {
    root.syncFromService()
    root.optionsOpen = true
  }

  function closeOptions() {
    root.optionsOpen = false
  }

  function close() {
    closeOptions()
  }

  function closeForPopoutSwitch() {
    closeOptions()
  }

  onPressed: function() { root.toggle() }

  Component.onCompleted: syncFromService()

  Connections {
    target: root.idleService
    enabled: root.idleService !== null
    ignoreUnknownSignals: true
    function onScreensaverOnAcSecondsChanged() { if (!root.optionsOpen) root.syncFromService() }
    function onScreensaverOnBatterySecondsChanged() { if (!root.optionsOpen) root.syncFromService() }
  }

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
    focusTarget: powerField.field
    contentWidth: optionsPanel.fittedContentWidth(root.menuWidth + Style.spacing.popupPadding * 2)
    contentHeight: optionsPanel.fittedContentHeight(optionsColumn.implicitHeight)

    Column {
      id: optionsColumn
      width: root.menuWidth
      spacing: Style.space(10)

      Text {
        text: "Screensaver"
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      NumberField {
        id: powerField
        width: parent.width
        fieldWidth: parent.width
        label: "On power (min)"
        from: 1
        to: 240
        stepSize: 1
        value: root.powerMinutes
        foreground: root.fg
        accent: root.accent
        fontFamily: root.fontFamily
        onModified: function(v) { root.commitMinutes("ac", v) }
      }

      NumberField {
        id: batteryField
        width: parent.width
        fieldWidth: parent.width
        label: "On battery (min)"
        from: 1
        to: 240
        stepSize: 1
        value: root.batteryMinutes
        foreground: root.fg
        accent: root.accent
        fontFamily: root.fontFamily
        onModified: function(v) { root.commitMinutes("battery", v) }
      }
    }
  }
}

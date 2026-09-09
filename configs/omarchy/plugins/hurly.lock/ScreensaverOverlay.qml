import QtQuick
import Quickshell.Io
import qs.Commons

FocusScope {
  id: root

  property string logoPath: ""
  property real hue: 0
  property var logoLines: []
  property real originX: -1
  property real originY: -1
  property bool inputArmed: false

  signal dismissed()

  function dismiss() {
    if (!root.inputArmed) return
    root.dismissed()
  }

  function grabInput() {
    keySink.forceActiveFocus()
  }

  function startArm() {
    originX = -1
    originY = -1
    inputArmed = false
    inputArmTimer.restart()
    grabInput()
  }

  focus: visible
  z: 10

  // Created already visible when idle locks: onVisibleChanged does not fire.
  Component.onCompleted: if (visible) startArm()

  onVisibleChanged: {
    if (!visible) {
      inputArmed = false
      inputArmTimer.stop()
      return
    }
    startArm()
  }

  // Ignore leftover repeats from the idle event, then any key dismisses.
  Timer {
    id: inputArmTimer
    interval: 250
    repeat: false
    onTriggered: {
      root.inputArmed = true
      root.grabInput()
    }
  }

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    event.accepted = true
    if (root.inputArmed) root.dismiss()
  }

  FileView {
    path: root.logoPath
    printErrors: false
    onLoaded: {
      var raw = String(text())
      root.logoLines = raw.replace(/\s+$/, "").split("\n")
      canvas.requestPaint()
    }
    onLoadFailed: {
      root.logoLines = [
        "                 ▄▄▄",
        " ▄█████▄    ▄███████████▄    ▄███████   ▄███████   ▄███████   ▄█   █▄    ▄█   █▄",
        "███   ███  ███   ███   ███  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███",
        "███   ███  ███   ███   ███  ███   ███  ███   ███  ███   █▀   ███   ███  ███   ███",
        "███   ███  ███   ███   ███ ▄███▄▄▄███ ▄███▄▄▄██▀  ███       ▄███▄▄▄███▄ ███▄▄▄███",
        "███   ███  ███   ███   ███ ▀███▀▀▀███ ▀███▀▀▀▀    ███      ▀▀███▀▀▀███  ▀▀▀▀▀▀███",
        "███   ███  ███   ███   ███  ███   ███ ██████████  ███   █▄   ███   ███  ▄██   ███",
        "███   ███  ███   ███   ███  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███",
        " ▀█████▀    ▀█   ███   █▀   ███   █▀   ███   ███  ███████▀   ███   █▀    ▀█████▀",
        "                                       ███   █▀"
      ]
      canvas.requestPaint()
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent

    onPaint: {
      var ctx = getContext("2d")
      var w = width
      var h = height
      ctx.fillStyle = "#000000"
      ctx.fillRect(0, 0, w, h)

      var lines = root.logoLines
      if (!lines || lines.length === 0) return

      var rows = lines.length
      var cols = 0
      for (var i = 0; i < rows; i++) {
        if (lines[i].length > cols) cols = lines[i].length
      }
      if (cols < 1) return

      var cellH = Math.max(8, Math.floor((h * 0.62) / rows))
      var cellW = Math.max(6, Math.floor((w * 0.86) / cols))
      var fontPx = Math.min(cellH, Math.floor(cellW / 0.58))
      var charW = fontPx * 0.62
      var charH = fontPx
      var artW = cols * charW
      var artH = rows * charH
      var ox = (w - artW) / 2
      var oy = (h - artH) / 2

      ctx.font = fontPx + "px " + Style.font.family
      ctx.textBaseline = "top"

      for (var r = 0; r < rows; r++) {
        var line = lines[r]
        for (var c = 0; c < line.length; c++) {
          var ch = line.charAt(c)
          if (ch === " ") continue
          var hh = (root.hue + c * 9 + r * 3) % 360
          ctx.fillStyle = "hsl(" + hh + ", 92%, 62%)"
          ctx.fillText(ch, ox + c * charW, oy + r * charH)
        }
      }
    }
  }

  MouseArea {
    id: grab
    anchors.fill: parent
    z: 21
    hoverEnabled: true
    acceptedButtons: Qt.AllButtons
    focus: false
    onPressed: if (root.inputArmed) root.dismiss()
    onPositionChanged: function(mouse) {
      if (!root.inputArmed) return
      if (root.originX < 0) {
        root.originX = mouse.x
        root.originY = mouse.y
        return
      }
      var dx = mouse.x - root.originX
      var dy = mouse.y - root.originY
      if (dx < 0) dx = -dx
      if (dy < 0) dy = -dy
      if (dx + dy > 24) root.dismiss()
    }
  }

  // Session-lock surfaces often have no focused item. An invisible field is
  // the reliable way to receive keys on this compositor.
  TextInput {
    id: keySink
    anchors.fill: parent
    z: 20
    opacity: 0
    color: "transparent"
    cursorVisible: false
    clip: true
    enabled: root.visible
    activeFocusOnPress: true
    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
    echoMode: TextInput.NoEcho
    onTextChanged: {
      if (text.length === 0) return
      text = ""
      if (root.inputArmed) root.dismiss()
    }
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      event.accepted = true
      if (root.inputArmed) root.dismiss()
    }
  }

  Timer {
    interval: 120
    running: root.visible
    repeat: true
    onTriggered: {
      root.hue = (root.hue + 6) % 360
      canvas.requestPaint()
    }
  }
}

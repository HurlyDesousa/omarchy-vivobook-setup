import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null

  property string baseHex: "#ffffff"
  property int brightness: 100
  property bool kbdEnabled: false
  property bool autostart: true
  property bool autoOff: true
  property bool applyingFromFile: false
  property bool started: false
  property bool applyPending: false
  property string lastWritten: ""

  readonly property bool backlightOn: kbdEnabled && brightness > 0
  readonly property string actualHex: {
    if (!kbdEnabled || brightness === 0) return "#000000"
    if (brightness === 100) return baseHex.toLowerCase()
    var h = baseHex.slice(1).toLowerCase()
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
    function sc(off) {
      var v = Math.max(0, Math.min(255, Math.round(parseInt(h.substr(off, 2), 16) * brightness / 100)))
      var s = v.toString(16)
      return s.length < 2 ? "0" + s : s
    }
    return "#" + sc(0) + sc(2) + sc(4)
  }

  Timer {
    id: applyTimer
    interval: 100
    repeat: false
    onTriggered: root._doApply()
  }

  Timer {
    id: saveTimer
    interval: 150
    repeat: false
    onTriggered: root._doSave()
  }

  FileView {
    id: stateFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/kbd-backlight"
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.loadFromText(text())
      if (!root.started) {
        root.started = true
        if (root.autostart) root._doApply(true)
      }
    }
    onFileChanged: reload()
  }

  Component.onCompleted: stateFile.reload()

  // One EC write at a time; a newer colour waits for the running one.
  Process {
    id: applyProc
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("kbd-backlight: x1e-ec-tool kb exited " + exitCode)
      if (root.applyPending) {
        root.applyPending = false
        root._doApply(false)
      }
    }
  }

  function loadFromText(raw) {
    var l = String(raw || "").trim()
    if (!l || l === "{}") return
    // Our own save echoing back can be older than the slider by now.
    if (l === root.lastWritten) return
    try {
      applyStateFromDisk(JSON.parse(l), false)
    } catch (e) {}
  }

  function applyStateFromDisk(d, applyEc) {
    if (!d || typeof d !== "object") return
    root.applyingFromFile = true
    var col = (d._base && /^#[0-9a-fA-F]{6}$/.test(d._base))
      ? d._base.toLowerCase()
      : ((d.hex && /^#[0-9a-fA-F]{6}$/.test(d.hex)) ? d.hex.toLowerCase() : null)
    if (col) root.baseHex = col
    if (typeof d.brightness === "number")
      root.brightness = Math.max(0, Math.min(100, Math.round(d.brightness)))
    if (typeof d.enabled === "boolean")
      root.kbdEnabled = d.enabled
    if (typeof d.autostart === "boolean")
      root.autostart = d.autostart
    if (typeof d.auto_off === "boolean")
      root.autoOff = d.auto_off
    root.applyingFromFile = false
    if (applyEc && root.autostart) root._doApply()
  }

  // onLoad: a plugin reload while the idle dim holds the keyboard dark must
  // not relight it; omarchy-idle-dim keeps its state file only while dimmed.
  function _doApply(onLoad) {
    if (applyProc.running) {
      root.applyPending = true
      return
    }
    var hex = actualHex
    if (!/^#[0-9a-f]{6}$/.test(hex)) return
    applyProc.command = onLoad
      ? ["bash", "-c", "[[ -e ${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/omarchy-idle-dim.state ]] && exit 0; " +
          "exec timeout 3 /usr/local/bin/x1e-ec-tool kb \"$1\"", "bash", hex]
      : ["timeout", "3", "/usr/local/bin/x1e-ec-tool", "kb", hex]
    applyProc.running = true
  }

  function _doSave() {
    var en = kbdEnabled && brightness > 0
    var payload = JSON.stringify({
      hex: actualHex,
      enabled: en,
      _base: baseHex.toLowerCase(),
      brightness: brightness,
      autostart: autostart,
      auto_off: autoOff
    })
    root.lastWritten = payload
    Quickshell.execDetached(["bash", "-c",
      "d=\"$HOME/.local/state/omarchy\";" +
      " mkdir -p \"$d\" &&" +
      " t=$(mktemp \"$d/kbd-backlight.XXXXXX\") &&" +
      " printf '%s\\n' \"$1\" > \"$t\" &&" +
      " mv \"$t\" \"$d/kbd-backlight\"", "bash", payload])
  }

  function applyAndSave() {
    if (root.applyingFromFile) return
    applyTimer.restart()
    saveTimer.restart()
  }

  function persistNow() {
    applyTimer.stop()
    saveTimer.stop()
    root._doApply(false)
    root._doSave()
  }

  function ensureOn() {
    root.kbdEnabled = true
    if (root.brightness === 0) root.brightness = 100
  }

  function toggle() {
    if (root.backlightOn) root.kbdEnabled = false
    else root.ensureOn()
    root.persistNow()
  }

  function setBaseHex(value) {
    var hex = normaliseHex(value)
    if (!hex) return
    root.baseHex = hex
    root.ensureOn()
    root.applyAndSave()
  }

  function setBrightness(value) {
    root.brightness = Math.max(0, Math.min(100, Math.round(value)))
    root.applyAndSave()
  }

  function setAutostart(value) {
    root.autostart = !!value
    saveTimer.restart()
  }

  function setAutoOff(value) {
    root.autoOff = !!value
    saveTimer.restart()
  }

  function normaliseHex(s) {
    s = String(s || "").trim().toLowerCase()
    if (/^#[0-9a-f]{6}$/.test(s)) return s
    if (/^#[0-9a-f]{3}$/.test(s))
      return "#" + s[1] + s[1] + s[2] + s[2] + s[3] + s[3]
    if (/^[0-9a-f]{6}$/.test(s)) return "#" + s
    if (/^[0-9a-f]{3}$/.test(s))
      return "#" + s[0] + s[0] + s[1] + s[1] + s[2] + s[2]
    return null
  }

  IpcHandler {
    target: "kbd-backlight"

    function status(): string {
      return JSON.stringify({
        enabled: root.backlightOn,
        hex: root.actualHex,
        base: root.baseHex,
        brightness: root.brightness,
        autostart: root.autostart,
        auto_off: root.autoOff
      })
    }

    function toggle(): string {
      root.toggle()
      return root.backlightOn ? "on" : "off"
    }

    function setHex(value: string): string {
      root.setBaseHex(value)
      return root.actualHex
    }

    function setBrightness(value: string): string {
      root.setBrightness(Number(value))
      return String(root.brightness)
    }

    function setAutostart(value: string): string {
      var on = value === "true" || value === "1" || value === "on"
      root.setAutostart(on)
      return root.autostart ? "on" : "off"
    }

    function setAutoOff(value: string): string {
      var on = value === "true" || value === "1" || value === "on"
      root.setAutoOff(on)
      return root.autoOff ? "on" : "off"
    }
  }
}

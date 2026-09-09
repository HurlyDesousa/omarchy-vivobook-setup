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
        if (root.autostart) root._doApply()
      }
    }
    onFileChanged: reload()
  }

  Component.onCompleted: {
    if (!stateFile.running) stateFile.reload()
  }

  function loadFromText(raw) {
    var l = String(raw || "").trim()
    if (!l || l === "{}") return
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

  function _doApply() {
    var hex = actualHex
    Quickshell.execDetached(["bash", "-c",
      "ec=/usr/local/bin/x1e-ec-tool;" +
      " \"$ec\" kb '" + hex + "' 2>/dev/null ||" +
      " sudo -n \"$ec\" kb '" + hex + "' 2>/dev/null || true"])
  }

  function _doSave() {
    var en = kbdEnabled && brightness > 0
    var payload = '{"hex":"' + actualHex + '"' +
      ',"enabled":' + (en ? "true" : "false") +
      ',"_base":"' + baseHex.toLowerCase() + '"' +
      ',"brightness":' + brightness +
      ',"autostart":' + (autostart ? "true" : "false") +
      ',"auto_off":' + (autoOff ? "true" : "false") + '}'
    Quickshell.execDetached(["bash", "-c",
      "d=\"$HOME/.local/state/omarchy\";" +
      " mkdir -p \"$d\" &&" +
      " t=$(mktemp \"$d/kbd-backlight.XXXXXX\") &&" +
      " printf '%s\\n' '" + payload + "' > \"$t\" &&" +
      " mv \"$t\" \"$d/kbd-backlight\""])
  }

  function applyAndSave() {
    if (root.applyingFromFile) return
    applyTimer.restart()
    saveTimer.restart()
  }

  function persistNow() {
    applyTimer.stop()
    saveTimer.stop()
    root._doApply()
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
    root.baseHex = value
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
        brightness: root.brightness
      })
    }

    function toggle(): string {
      root.toggle()
      return root.backlightOn ? "on" : "off"
    }
  }
}

// Omarchy bar widget: keyboard RGB backlight control.
// Drives /usr/local/bin/x1e-ec-tool kb '#rrggbb' (solid color, ASUS Vivobook x1e).
//
// State file (Omarchy idle-helper contract):
//   ~/.local/state/omarchy/kbd-backlight
//   JSON: {"hex":"#rrggbb","enabled":true,"autostart":true,"auto_off":true,...}
//   Written atomically (mktemp + rename) on every change AND on startup apply.
//
//   Fields read by external helpers:
//     hex      — actual colour currently sent to EC (for idle restore)
//     enabled  — whether keyboard backlight is on (kbdEnabled && brightness > 0)
//     auto_off — bool gate only: when true, omarchy-idle-dim blacks RGB at idle.dim
//                (Omarchy Idle Service; timing from shell.shellConfig.idle.dim)
//     autostart— when true, restore last colour/brightness/enabled on session start
//
// Panel pattern: Panel (qs.Ui) + KeyboardPanel (qs.Ui) anchored to the bar button.
// This is the same architecture as omarchy.agents / omarchy.weather and avoids
// the QtQuick.Controls Popup which is clipped by the layer-shell PanelWindow.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "sw.art.kbd-backlight"
    manageIpc: false

    // Injected by omarchy-shell when available (idle Service contract).
    property var shell: null

    readonly property int defaultDimSeconds: 180
    readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle ? shell.shellConfig.idle : ({})
    readonly property int dimTimeoutSeconds: {
        var fromShell = secondsFromConfig(idleConfig.dim, -1)
        if (fromShell >= 0) return fromShell
        if (shellJsonDimSeconds >= 0) return shellJsonDimSeconds
        return defaultDimSeconds
    }

    property int shellJsonDimSeconds: -1

    // ── Live state ──────────────────────────────────────────────────────────
    // baseHex: full-brightness chosen color (#rrggbb).
    // brightness: 0–100; scales RGB channels of baseHex linearly.
    // kbdEnabled: explicit off toggle.
    // actualHex: computed color sent to EC and written as "hex" in state file.
    property string  baseHex:    "#ffffff"
    property int     brightness: 100
    property bool    kbdEnabled: true

    // ── Settings state ──────────────────────────────────────────────────────
    // autostart: restore last color/brightness/enabled on session/bar start.
    // autoOff:   bool gate for omarchy-idle-dim at idle.dim (written as auto_off).
    // showSettings: controls whether gear panel is open in the KeyboardPanel.
    property bool autostart:    true
    property bool autoOff:      true
    property bool showSettings: false

    readonly property string actualHex: {
        if (!kbdEnabled || brightness === 0) return "#000000"
        if (brightness === 100) return baseHex.toLowerCase()
        var h = baseHex.slice(1).toLowerCase()
        if (h.length === 3) h = h[0]+h[0]+h[1]+h[1]+h[2]+h[2]
        function sc(off) {
            var v = Math.max(0, Math.min(255,
                Math.round(parseInt(h.substr(off, 2), 16) * brightness / 100)))
            var s = v.toString(16)
            return s.length < 2 ? "0"+s : s
        }
        return "#" + sc(0) + sc(2) + sc(4)
    }

    // ── Debounce timers ─────────────────────────────────────────────────────
    // Prevents spamming the EC or disk during slider drags.
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

    // ── Processes ───────────────────────────────────────────────────────────
    Process {
        id: ecProc
        onRunningChanged: {
            if (!running && applyTimer.running) applyTimer.restart()
        }
    }

    Process {
        id: saveProc
        onRunningChanged: {
            if (!running && saveTimer.running) saveTimer.restart()
        }
    }

    // ── Startup: read saved state then apply ────────────────────────────────
    Process {
        id: initProc
        stdout: SplitParser {
            onRead: function(line) {
                var l = line.trim()
                if (!l || l === "{}") return
                try {
                    var d = JSON.parse(l)
                    // Restore base colour for the UI.
                    // _base is the pre-scaled colour; fall back to hex (actualHex at save time).
                    var col = (d._base && /^#[0-9a-fA-F]{6}$/.test(d._base))
                        ? d._base.toLowerCase()
                        : ((d.hex && /^#[0-9a-fA-F]{6}$/.test(d.hex))
                            ? d.hex.toLowerCase() : null)
                    if (col) root.baseHex = col

                    if (typeof d.brightness === "number")
                        root.brightness = Math.max(0, Math.min(100, Math.round(d.brightness)))

                    if (typeof d.enabled === "boolean")
                        root.kbdEnabled = d.enabled

                    if (typeof d.autostart === "boolean")
                        root.autostart = d.autostart

                    if (typeof d.auto_off === "boolean")
                        root.autoOff = d.auto_off
                } catch(e) {}
            }
        }
        onRunningChanged: {
            if (!running) {
                // Only apply to the EC if autostart is enabled.
                if (root.autostart) root._doApply()
                // Always write the canonical prefs file (normalises any old format).
                root._doSave()
            }
        }
    }

    Component.onCompleted: {
        initProc.command = ["/bin/bash", "-c",
            "cat \"$HOME/.local/state/omarchy/kbd-backlight\" 2>/dev/null" +
            " || echo '{}'"]
        initProc.running = true
        parseShellJsonIdle()
    }

    FileView {
        id: shellJsonFile
        path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.parseShellJsonIdle()
        onFileChanged: reload()
    }

    // ── Internal helpers ────────────────────────────────────────────────────
    function secondsFromConfig(value, fallback) {
        var n = Number(value)
        if (!isFinite(n) || n < 0) return fallback
        return Math.floor(n)
    }

    function formatDimTimeout(seconds) {
        var s = Math.max(0, Math.floor(seconds))
        if (s >= 60 && s % 60 === 0) return (s / 60) + " min"
        return s + "s"
    }

    function parseShellJsonIdle() {
        try {
            var parsed = JSON.parse(shellJsonFile.text() || "{}")
            if (parsed && parsed.idle)
                root.shellJsonDimSeconds = secondsFromConfig(parsed.idle.dim, -1)
        } catch (e) {}
    }
    function _doApply() {
        if (ecProc.running) { applyTimer.restart(); return }
        var hex = actualHex
        ecProc.command = ["/bin/bash", "-c",
            "ec=/usr/local/bin/x1e-ec-tool;" +
            " \"$ec\" kb '" + hex + "' 2>/dev/null ||" +
            " sudo -n \"$ec\" kb '" + hex + "' 2>/dev/null || true"]
        ecProc.running = true
    }

    // Writes the canonical prefs file atomically.
    // Fields:
    //   hex      — actualHex (exact colour sent to EC; idle-helper restore target)
    //   enabled  — whether backlight is effectively on
    //   _base    — pre-scaled base colour (for UI restore across sessions)
    //   brightness — 0-100 (for UI restore)
    //   autostart  — restore on session start (Omarchy / bar restart)
    //   auto_off   — bool gate for omarchy-idle-dim (timing from idle.dim, not stored here)
    function _doSave() {
        if (saveProc.running) { saveTimer.restart(); return }
        var en = kbdEnabled && brightness > 0
        var payload = '{"hex":"' + actualHex + '"' +
                      ',"enabled":' + (en ? "true" : "false") +
                      ',"_base":"' + baseHex.toLowerCase() + '"' +
                      ',"brightness":' + brightness +
                      ',"autostart":' + (autostart ? "true" : "false") +
                      ',"auto_off":' + (autoOff ? "true" : "false") + '}'
        saveProc.command = ["/bin/bash", "-c",
            "d=\"$HOME/.local/state/omarchy\";" +
            " mkdir -p \"$d\" &&" +
            " t=$(mktemp \"$d/kbd-backlight.XXXXXX\") &&" +
            " printf '%s\\n' '" + payload + "' > \"$t\" &&" +
            " mv \"$t\" \"$d/kbd-backlight\""]
        saveProc.running = true
    }

    // Public: call after any state change that should be persisted + applied.
    function applyAndSave() {
        applyTimer.restart()
        saveTimer.restart()
    }

    // Stay Awake pattern: left-click on the bar icon toggles power.
    function toggleBacklight() {
        if (root.kbdEnabled && root.brightness > 0) {
            root.kbdEnabled = false
        } else {
            root.kbdEnabled = true
            if (root.brightness === 0) root.brightness = 100
        }
        root.applyAndSave()
    }

    function openOptions() {
        root.showSettings = false
        if (!root.opened) root.open()
    }

    function closeOptions() {
        root.showSettings = false
        if (root.opened) root.close()
    }

    // Validate and normalise a hex string to lowercase #rrggbb, or return null.
    function normaliseHex(s) {
        s = s.trim().toLowerCase()
        if (/^#[0-9a-f]{6}$/.test(s)) return s
        if (/^#[0-9a-f]{3}$/.test(s))
            return "#" + s[1]+s[1]+s[2]+s[2]+s[3]+s[3]
        if (/^[0-9a-f]{6}$/.test(s)) return "#" + s
        if (/^[0-9a-f]{3}$/.test(s))
            return "#" + s[0]+s[0]+s[1]+s[1]+s[2]+s[2]
        return null
    }

    // ── Bar button ──────────────────────────────────────────────────────────
    implicitWidth:  button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: (root.kbdEnabled && root.brightness > 0) ? "󰌌" : "󰌎"
        tooltipText: (root.kbdEnabled && root.brightness > 0)
            ? ("Keyboard: " + root.actualHex + " @ " + root.brightness + "%")
            : "Keyboard: off"
        // Stay Awake pattern: left-click toggles on/off; right-click opens options.
        onPressed: function(b) {
            if (b === Qt.RightButton) {
                if (root.opened) root.closeOptions()
                else root.openOptions()
                return
            }
            root.toggleBacklight()
        }
    }

    // ── Panel ───────────────────────────────────────────────────────────────
    // KeyboardPanel is a layer-shell surface anchored to the bar button.
    // Weather / Task Manager pattern: no scrim, KeyboardPanel outer border only.
    KeyboardPanel {
        id: kbdPanel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        contentWidth: kbdPanel.fittedContentWidth(Style.space(320))
        contentHeight: kbdPanel.fittedContentHeight(panelContent.implicitHeight, Style.space(360))

        Item {
            anchors.fill: parent
            clip: true

            Column {
                id: panelContent
                width: parent.width
                spacing: 0

                // ── Header row: title + on/off toggle + gear ────────────
                Item {
                    width: parent.width
                    height: headerRow.implicitHeight + Style.space(20)
                    RowLayout {
                        id: headerRow
                        width: parent.width - Style.space(32)
                        x: Style.space(16)
                        y: Style.space(12)
                        spacing: Style.space(8)

                        Label {
                            text: "Keyboard Backlight"
                            font.pixelSize: Style.font.title
                            font.bold: true
                            color: root.bar.foreground
                            font.family: root.bar.fontFamily
                            Layout.fillWidth: true
                        }

                        ToggleSwitch {
                            checked: root.kbdEnabled && root.brightness > 0
                            foreground: root.bar.foreground
                            onToggled: root.toggleBacklight()
                        }

                        Rectangle {
                            width: Style.space(30); height: Style.space(30)
                            radius: Style.cornerRadius
                            color: root.showSettings
                                ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Label {
                                anchors.centerIn: parent
                                text: "󰒓"
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.subtitle
                                color: root.showSettings
                                    ? Style.hoverStateColor(root.bar.foreground, Color.accent)
                                    : Qt.darker(root.bar.foreground, 1.4)

                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showSettings = !root.showSettings
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Style.spacing.hairline
                    color: root.bar.foreground
                    opacity: 0.12
                }

                // ── Main controls (shown when showSettings is false) ───────
                Column {
                    visible: !root.showSettings
                    width: parent.width - Style.space(32)
                    x: Style.space(16)
                    spacing: Style.space(10)
                    topPadding: Style.space(12)
                    bottomPadding: Style.space(14)

                    // ── Colour presets ────────────────────────────────────
                    Row {
                        spacing: Style.space(6)
                        width: parent.width

                        Repeater {
                            model: ["#ffffff", "#ffd080", "#ff3333", "#ff8800",
                                    "#33ee44", "#00eeee", "#3388ff", "#cc44ff"]
                            delegate: Rectangle {
                                required property string modelData
                                property string swatch: modelData
                                width: Style.space(26); height: Style.space(26)
                                radius: Style.cornerRadius
                                color: swatch
                                border.width: 2
                                border.color: (root.baseHex.toLowerCase() === swatch)
                                    ? root.bar.foreground : "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.baseHex = swatch
                                        if (!root.kbdEnabled) root.kbdEnabled = true
                                        if (root.brightness === 0) root.brightness = 100
                                        root.applyAndSave()
                                    }
                                }
                            }
                        }
                    }

                    // ── Brightness slider ─────────────────────────────────
                    RowLayout {
                        width: parent.width
                        spacing: Style.space(8)

                        Label {
                            text: "Bright"
                            color: Qt.darker(root.bar.foreground, 1.4)
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.bodySmall
                        }

                        Slider {
                            id: brightSlider
                            from: 0; to: 100; stepSize: 1
                            value: root.brightness
                            Layout.fillWidth: true

                            handle: Rectangle {
                                x: brightSlider.leftPadding +
                                   brightSlider.visualPosition * (brightSlider.availableWidth - width)
                                y: brightSlider.topPadding +
                                   brightSlider.availableHeight / 2 - height / 2
                                implicitWidth: Style.space(14)
                                implicitHeight: Style.space(14)
                                radius: Style.space(7)
                                color: Color.accent
                                border.color: Color.popups.background
                                border.width: 1
                            }

                            background: Item {
                                x: brightSlider.leftPadding
                                y: brightSlider.topPadding + brightSlider.availableHeight / 2 - Style.space(2)
                                width: brightSlider.availableWidth
                                height: Style.space(4)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: Qt.darker(root.bar.foreground, 2.2)
                                    Rectangle {
                                        width: brightSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        color: Color.accent
                                    }
                                }
                            }

                            onMoved: {
                                root.brightness = Math.round(value)
                                root.applyAndSave()
                            }
                        }

                        Label {
                            text: root.brightness + "%"
                            color: root.bar.foreground
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.bodySmall
                            Layout.minimumWidth: Style.space(36)
                        }
                    }
                }

                // ── Settings panel (shown when showSettings is true) ───────
                Column {
                    visible: root.showSettings
                    width: parent.width - Style.space(32)
                    x: Style.space(16)
                    spacing: Style.space(10)
                    topPadding: Style.space(12)
                    bottomPadding: Style.space(14)

                    Label {
                        text: "Colour"
                        color: Qt.darker(root.bar.foreground, 1.4)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        font.letterSpacing: 1
                    }

                    // ── Hex color input ───────────────────────────────────
                    RowLayout {
                        spacing: Style.space(8)
                        width: parent.width

                        Label {
                            text: "Hex"
                            color: Qt.darker(root.bar.foreground, 1.4)
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.bodySmall
                        }

                        TextField {
                            id: hexInput
                            text: root.baseHex
                            font.family: "monospace"
                            font.pixelSize: Style.font.bodySmall
                            color: root.bar.foreground
                            Layout.fillWidth: true
                            leftPadding: Style.space(6)
                            rightPadding: Style.space(6)
                            topPadding: Style.space(4)
                            bottomPadding: Style.space(4)
                            background: Rectangle {
                                color: Color.popups.background
                                radius: Style.cornerRadius
                                border.color: hexInput.activeFocus
                                    ? Color.accent : Color.popups.border
                                border.width: 1
                            }
                            onEditingFinished: {
                                var v = root.normaliseHex(text)
                                if (!v) { text = root.baseHex; return }
                                root.baseHex = v
                                text = v
                                if (!root.kbdEnabled) root.kbdEnabled = true
                                if (root.brightness === 0) root.brightness = 100
                                root.applyAndSave()
                            }
                            Connections {
                                target: root
                                function onBaseHexChanged() {
                                    if (!hexInput.activeFocus) hexInput.text = root.baseHex
                                }
                            }
                        }

                        Rectangle {
                            width: Style.space(22); height: Style.space(22)
                            radius: Style.cornerRadius
                            color: root.actualHex
                            border.color: Color.popups.border
                            border.width: 1
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Style.spacing.hairline
                        color: root.bar.foreground
                        opacity: 0.12
                    }

                    Label {
                        text: "Behaviour"
                        color: Qt.darker(root.bar.foreground, 1.4)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        font.letterSpacing: 1
                    }

                    Toggle {
                        width: parent.width
                        label: "Autostart"
                        description: "Restore on session"
                        checked: root.autostart
                        foreground: root.bar.foreground
                        fontFamily: root.bar.fontFamily
                        onClicked: {
                            root.autostart = !root.autostart
                            saveTimer.restart()
                        }
                    }

                    Toggle {
                        width: parent.width
                        label: "Auto-off on idle"
                        description: "Follows display auto-dim (" + root.formatDimTimeout(root.dimTimeoutSeconds) + ")"
                        checked: root.autoOff
                        foreground: root.bar.foreground
                        fontFamily: root.bar.fontFamily
                        onClicked: {
                            root.autoOff = !root.autoOff
                            saveTimer.restart()
                        }
                    }
                }
            }
        }
    }
}

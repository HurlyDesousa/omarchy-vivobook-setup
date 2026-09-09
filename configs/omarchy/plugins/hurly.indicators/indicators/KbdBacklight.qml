import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  readonly property var kbd: {
    var sh = bar && bar.shell ? bar.shell : null
    if (!sh) return null
    var services = sh._services || {}
    return services["sw.art.kbd-backlight"] || null
  }

  property bool optionsOpen: false
  property bool showSettings: false
  readonly property bool popoutSwitchClosing: false
  readonly property int defaultDimSeconds: 180
  readonly property var idleConfig: {
    var sh = bar && bar.shell ? bar.shell : null
    return sh && sh.shellConfig && sh.shellConfig.idle ? sh.shellConfig.idle : ({})
  }
  readonly property int dimTimeoutSeconds: {
    var n = Number(idleConfig.dim)
    if (isFinite(n) && n >= 0) return Math.floor(n)
    return defaultDimSeconds
  }

  active: kbd ? kbd.backlightOn : false
  activeText: "󰌌"
  inactiveText: "󰌌"
  activeTooltipText: "Keyboard backlight on"
  inactiveTooltipText: "Keyboard backlight off"
  useActiveColor: false

  function formatDimTimeout(seconds) {
    var s = Math.max(0, Math.floor(seconds))
    if (s >= 60 && s % 60 === 0) return (s / 60) + " min"
    return s + "s"
  }

  function toggle() {
    if (root.kbd) root.kbd.toggle()
  }

  function openOptions() {
    root.showSettings = false
    root.optionsOpen = true
  }

  function closeOptions() {
    root.showSettings = false
    root.optionsOpen = false
  }

  function close() { closeOptions() }
  function closeForPopoutSwitch() { closeOptions() }

  onPressed: function() { root.toggle() }

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
    id: kbdPanel
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.optionsOpen
    contentWidth: kbdPanel.fittedContentWidth(Style.space(320))
    contentHeight: kbdPanel.fittedContentHeight(panelContent.implicitHeight, Style.space(360))

    Item {
      anchors.fill: parent
      clip: true

      Column {
        id: panelContent
        width: parent.width
        spacing: 0

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
              checked: root.kbd ? root.kbd.backlightOn : false
              foreground: root.bar.foreground
              onToggled: root.toggle()
            }

            Rectangle {
              width: Style.space(30); height: Style.space(30)
              radius: Style.cornerRadius
              color: root.showSettings
                ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

              Label {
                anchors.centerIn: parent
                text: "󰒓"
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.subtitle
                color: root.showSettings
                  ? Style.hoverStateColor(root.bar.foreground, Color.accent)
                  : Qt.darker(root.bar.foreground, 1.4)
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

        Column {
          visible: !root.showSettings
          width: parent.width - Style.space(32)
          x: Style.space(16)
          spacing: Style.space(10)
          topPadding: Style.space(12)
          bottomPadding: Style.space(14)

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
                border.color: (root.kbd && root.kbd.baseHex.toLowerCase() === swatch)
                  ? root.bar.foreground : "transparent"

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.kbd) root.kbd.setBaseHex(swatch)
                }
              }
            }
          }

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
              value: root.kbd ? root.kbd.brightness : 100
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

              onMoved: if (root.kbd) root.kbd.setBrightness(value)
            }

            Label {
              text: (root.kbd ? root.kbd.brightness : 0) + "%"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              Layout.minimumWidth: Style.space(36)
            }
          }
        }

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
              text: root.kbd ? root.kbd.baseHex : "#ffffff"
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
                border.color: hexInput.activeFocus ? Color.accent : Color.popups.border
                border.width: 1
              }
              onEditingFinished: {
                if (!root.kbd) return
                var v = root.kbd.normaliseHex(text)
                if (!v) { text = root.kbd.baseHex; return }
                root.kbd.setBaseHex(v)
                text = v
              }
              Connections {
                target: root.kbd
                enabled: root.kbd !== null
                ignoreUnknownSignals: true
                function onBaseHexChanged() {
                  if (!hexInput.activeFocus && root.kbd) hexInput.text = root.kbd.baseHex
                }
              }
            }

            Rectangle {
              width: Style.space(22); height: Style.space(22)
              radius: Style.cornerRadius
              color: root.kbd ? root.kbd.actualHex : "#000000"
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
            checked: root.kbd ? root.kbd.autostart : true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: if (root.kbd) root.kbd.setAutostart(!root.kbd.autostart)
          }

          Toggle {
            width: parent.width
            label: "Auto-off on idle"
            description: "Follows display auto-dim (" + root.formatDimTimeout(root.dimTimeoutSeconds) + ")"
            checked: root.kbd ? root.kbd.autoOff : true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: if (root.kbd) root.kbd.setAutoOff(!root.kbd.autoOff)
          }
        }
      }
    }
  }
}

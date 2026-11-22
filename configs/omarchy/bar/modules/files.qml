import QtQuick
import Quickshell

Item {
  id: root
  // Injected by the bar loader (do not mark these readonly).
  property var bar: null
  property var settings: ({})

  readonly property int iconSize: 16
  implicitWidth: (bar && bar.vertical) ? (bar.barSize || 28) : (iconSize + 12)
  implicitHeight: bar ? bar.barSize : 26

  Image {
    id: icon
    anchors.centerIn: parent
    width: root.iconSize
    height: root.iconSize
    sourceSize.width: root.iconSize * 2
    sourceSize.height: root.iconSize * 2
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    source: {
      var themed = Quickshell.iconPath("org.gnome.Nautilus", true)
      if (themed && String(themed).length) return themed
      return "file:///usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg"
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.bar) root.bar.showTooltip(root, "Files")
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: {
      if (root.bar) root.bar.run("omarchy-launch-or-focus org.gnome.Nautilus omarchy-launch-nautilus")
    }
  }
}

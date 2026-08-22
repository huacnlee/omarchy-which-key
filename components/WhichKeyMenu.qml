import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Popup {
  id: root

  required property Item anchorItem
  property int gap: Style.space(4)
  default property alias menuItems: menuContent.data

  width: Style.space(190)
  padding: Style.space(6)
  modal: false
  focus: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  function reposition() {
    if (!opened || !anchorItem || !parent) return
    var point = anchorItem.mapToItem(parent, 0, 0)
    var preferredX = point.x + anchorItem.width - width
    var below = point.y + anchorItem.height + gap
    var above = point.y - height - gap
    x = Math.max(0, Math.min(preferredX, parent.width - width))
    y = below + height <= parent.height ? below : Math.max(0, above)
  }

  onOpened: Qt.callLater(reposition)
  onWidthChanged: if (opened) Qt.callLater(reposition)
  onHeightChanged: if (opened) Qt.callLater(reposition)

  background: BorderSurface {
    color: Color.menu.background
    borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border,
                                   Math.max(1, Style.space(1)))
    radius: Style.cornerRadius
  }

  contentItem: Column {
    id: menuContent
    spacing: Style.space(2)
  }
}

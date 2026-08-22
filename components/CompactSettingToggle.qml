import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string label: ""
  property bool checked: false
  property color foreground: Color.foreground
  property color accent: Color.accent
  signal toggled()

  implicitHeight: Style.space(30)
  radius: Style.cornerRadius
  color: mouse.containsMouse
    ? Style.hoverFillFor(foreground, accent) : "transparent"
  borderSpec: Border.none()

  Text {
    textFormat: Text.PlainText
    anchors.left: parent.left
    anchors.leftMargin: 0
    anchors.right: toggle.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: root.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.weight: Font.Normal
    elide: Text.ElideRight
  }

  ToggleSwitch {
    id: toggle
    anchors.right: parent.right
    anchors.rightMargin: 0
    anchors.verticalCenter: parent.verticalCenter
    checked: root.checked
    foreground: root.foreground
    accent: root.accent
    interactive: false
    cursorRing: false
    trackHeight: Style.space(18)
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.ArrowCursor
    onClicked: root.toggled()
  }
}

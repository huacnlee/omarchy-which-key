import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string iconText: ""
  property string text: ""
  property bool external: false
  signal activated()

  implicitWidth: Style.space(178)
  implicitHeight: Style.space(32)
  radius: Style.cornerRadius
  color: mouse.containsMouse ? Color.menu.selectedBackground : "transparent"
  borderSpec: Border.none()

  Row {
    anchors.fill: parent
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    spacing: Style.space(8)

    Text {
      width: Style.space(18)
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignHCenter
      text: root.iconText
      color: mouse.containsMouse ? Color.menu.selectedText : Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    Text {
      width: parent.width - Style.space(18) - trailing.width - parent.spacing * 2
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: mouse.containsMouse ? Color.menu.selectedText : Color.menu.text
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      font.weight: Font.Normal
      elide: Text.ElideRight
    }

    Text {
      id: trailing
      width: root.external ? Style.space(14) : 0
      anchors.verticalCenter: parent.verticalCenter
      visible: root.external
      text: "󰏌"
      color: mouse.containsMouse ? Color.menu.selectedText : Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.external ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.activated()
  }
}

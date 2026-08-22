import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BorderSurface {
  id: card

  required property var viewModel
  required property real availableWidth
  readonly property var visibleRows: viewModel && viewModel.rows
    ? viewModel.rows.slice(0, 10) : []
  readonly property int pad: Style.space(10)
  readonly property int rowGap: Style.space(4)
  readonly property int keyWidth: Style.space(44)

  width: Math.min(content.implicitWidth + borderLeft + pad * 2 + borderRight,
                  availableWidth, Style.space(300))
  height: content.implicitHeight + borderTop + pad * 2 + borderBottom
  color: Color.popups.background
  borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border,
                                 Math.max(1, Style.space(1)))
  radius: Style.cornerRadius

  ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.topMargin: card.borderTop + card.pad
    anchors.rightMargin: card.borderRight + card.pad
    anchors.bottomMargin: card.borderBottom + card.pad
    anchors.leftMargin: card.borderLeft + card.pad
    spacing: Style.space(6)

    Text {
      text: card.viewModel ? card.viewModel.title : ""
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1.5
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(1, Style.space(1))
      color: Color.popups.border
    }

    ColumnLayout {
      spacing: card.rowGap

      Repeater {
        model: card.visibleRows

        delegate: RowLayout {
          required property var modelData
          spacing: Style.space(6)

          Text {
            Layout.preferredWidth: card.keyWidth
            text: modelData.label
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            Layout.fillWidth: true
            Layout.preferredWidth: Style.space(190)
            text: modelData.description
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}

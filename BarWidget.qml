import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  property var manifest: null
  moduleName: "huacnlee.which-key"
  ipcTarget: "huacnlee.which-key.settings"
  manageIpc: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string sourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : config.configHome + "/omarchy/plugins/huacnlee.which-key"
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Color.muted
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string integrationState: "disabled"
  property string actionError: ""
  property bool actionBusy: false

  WhichKeyConfig { id: config }

  function refreshStatus() {
    if (!sourceDir || statusProcess.running) return
    statusProcess.command = [sourceDir + "/scripts/integration-status"]
    statusProcess.running = true
  }

  function runIntegrationAction() {
    if (!sourceDir || actionBusy) return
    actionError = ""
    actionBusy = true
    var script = integrationState === "enabled"
      ? "disable-integration" : "enable-integration"
    actionProcess.command = [sourceDir + "/scripts/" + script]
    actionProcess.running = true
  }

  onOpenedChanged: if (opened) {
    refreshStatus()
    config.settingsFile.reload()
  }
  Component.onCompleted: refreshStatus()

  Process {
    id: statusProcess
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      var value = String(statusOutput.text || "").trim()
      root.integrationState = exitCode === 0 && /^(enabled|disabled|repair)$/.test(value)
        ? value : "repair"
    }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { id: actionErrorOutput; waitForEnd: true }
    onExited: function(exitCode) {
      root.actionBusy = false
      root.actionError = exitCode === 0 ? "" : String(actionErrorOutput.text || "Action failed").trim()
      root.refreshStatus()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "⌨"
    tooltipText: "Which Key settings"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Which Key"
            meta: "Shortcut guide settings"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "⌨"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Button {
            width: parent.width
            text: root.actionBusy ? (root.integrationState === "enabled" ? "Disabling…" : "Enabling…")
              : (root.integrationState === "enabled" ? "Disable"
                : (root.integrationState === "repair" ? "Repair" : "Enable"))
            foreground: root.foreground
            bordered: true
            enabled: !root.actionBusy
            onClicked: root.runIntegrationAction()
          }

          Text {
            visible: root.actionError !== "" || config.error !== ""
            width: parent.width
            text: root.actionError !== "" ? root.actionError : config.error
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          RowLayout {
            width: parent.width
            Text {
              text: "Delay"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
              text: config.delayMs + " ms"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 0
            maximum: 1000
            step: 50
            integer: true
            value: config.delayMs
            onReleased: function(value) { config.setDelay(value) }
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          PanelSectionHeader {
            text: "SHOW GUIDE FOR"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: config.combinations
              delegate: Button {
                required property var modelData
                width: parent.width
                leftAlign: true
                text: (config.maskEnabled(modelData.mask) ? "☑  " : "☐  ") + modelData.label
                foreground: root.foreground
                onClicked: config.setMask(modelData.mask, !config.maskEnabled(modelData.mask))
              }
            }
          }

          Row {
            spacing: Style.space(8)
            Button { text: "Select all"; foreground: root.foreground; bordered: true; onClicked: config.selectAll() }
            Button { text: "Clear all"; foreground: root.foreground; bordered: true; onClicked: config.clearAll() }
          }
        }
      }
    }
  }
}

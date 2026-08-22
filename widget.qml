import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "huacnlee.which-key"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string sourceDir: localPath(Qt.resolvedUrl("."))
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Color.muted
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool opened: panelController.open
  property bool popoutSwitchClosing: false

  property string integrationState: "disabled"
  property string actionError: ""
  property bool actionBusy: false

  WhichKeyConfig { id: config }
  PanelController { id: panelController }

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.substring(7)
    try { return decodeURIComponent(value) } catch (error) { return value }
  }

  function open() { panelController.show() }
  function close() { panelController.hide() }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { popoutSwitchClosing = false })
  }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(root, direction)
    return false
  }

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

  IpcHandler {
    target: "huacnlee.which-key.settings"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

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
            trailingControl: Component {
              Item {
                implicitWidth: menuButton.implicitWidth
                implicitHeight: menuButton.implicitHeight

                PanelActionButton {
                  id: menuButton
                  anchors.fill: parent
                  iconText: "⋮"
                  tooltipText: "Menu"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  focusable: true
                  onClicked: linkMenu.opened ? linkMenu.close() : linkMenu.open()
                }

                Popup {
                  id: linkMenu
                  x: menuButton.width - width
                  y: menuButton.height + Style.space(4)
                  width: Style.space(190)
                  padding: Style.space(6)
                  modal: false
                  focus: true
                  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                  background: BorderSurface {
                    color: Color.popups.background
                    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border,
                                                   Math.max(1, Style.space(1)))
                    radius: Style.cornerRadius
                  }
                  contentItem: Column {
                    spacing: Style.space(2)

                    Button {
                      width: parent.width
                      text: "Keybindings"
                      leftAlign: true
                      foreground: Color.popups.text
                      onClicked: {
                        linkMenu.close()
                        Quickshell.execDetached(["omarchy-launch-config-editor", config.configHome + "/hypr/bindings.lua"])
                      }
                    }

                    Button {
                      width: parent.width
                      text: "GitHub"
                      leftAlign: true
                      foreground: Color.popups.text
                      onClicked: {
                        linkMenu.close()
                        Qt.openUrlExternally("https://github.com/huacnlee/omarchy-which-key")
                      }
                    }

                    Button {
                      width: parent.width
                      text: "Twitter"
                      leftAlign: true
                      foreground: Color.popups.text
                      onClicked: {
                        linkMenu.close()
                        Qt.openUrlExternally("https://x.com/huacnlee")
                      }
                    }
                  }
                }
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
              delegate: Toggle {
                required property var modelData
                width: parent.width
                label: modelData.label
                checked: config.maskEnabled(modelData.mask)
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

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "components"
import "WhichKeyModel.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property int generation: 0
  property int modifierMask: 0
  property var bindings: []
  property var viewModel: ({ title: "NONE", rows: [], columns: [] })
  property var heldSuperKeys: ({})
  property bool bindingsReady: false
  property bool revealDue: false
  property int pendingLoadGeneration: 0
  property int lastEventSequence: 0
  property bool consumed: false

  WhichKeyConfig { id: config; sourceDir: root.sourceDir }
  Connections {
    target: config
    function onEnabledMasksChanged() { root.maybeReveal() }
  }

  readonly property string sourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir) : ""
  readonly property bool superHeld: heldSuperKeys.super_l === true
    || heldSuperKeys.super_r === true
  readonly property string focusedScreenName: Hyprland.focusedMonitor
    ? String(Hyprland.focusedMonitor.name) : ""

  function close() {
    opened = false
  }

  function copyHeldKeys() {
    var copy = {}
    for (var key in heldSuperKeys) copy[key] = heldSuperKeys[key]
    return copy
  }

  function pressSuper(key) {
    var name = String(key || "")
    if ((name !== "super_l" && name !== "super_r") || heldSuperKeys[name] === true)
      return

    var wasHeld = superHeld
    var next = copyHeldKeys()
    next[name] = true
    heldSuperKeys = next
    modifierMask = modifierMask | 64

    if (wasHeld) return

    generation += 1
    consumed = false
    opened = false
    bindingsReady = false
    revealDue = false
    bindings = []
    rebuildModel()
    revealTimer.restart()
    // The bar widget owns a separate config instance and the file is no longer
    // watched, so the guide re-reads its settings as each chord starts.
    config.reload()
    requestBindings(generation)
  }

  function releaseSuper(key) {
    var name = String(key || "")
    if (heldSuperKeys[name] !== true) return

    var next = copyHeldKeys()
    delete next[name]
    heldSuperKeys = next
    if (superHeld) return

    generation += 1
    modifierMask = modifierMask & ~64
    revealTimer.stop()
    revealDue = false
    bindingsReady = false
    pendingLoadGeneration = 0
    if (bindingProcess.running) bindingProcess.running = false
    close()
    consumed = false
  }

  function setModifiers(mask) {
    var numericMask = Number(mask)
    if (!isFinite(numericMask) || numericMask < 0) return
    modifierMask = Math.floor(numericMask)
    rebuildModel()
    maybeReveal()
  }

  function acceptState(sequence, mask) {
    var nextSequence = Number(sequence)
    var nextMask = Number(mask)
    if (!isFinite(nextSequence) || !isFinite(nextMask)
        || nextSequence <= lastEventSequence) return
    lastEventSequence = nextSequence

    var shouldHold = (nextMask & 64) !== 0
    if (shouldHold && !superHeld) pressSuper("super_l")
    else if (!shouldHold && superHeld) releaseSuper("super_l")
    setModifiers(nextMask)
  }

  function acceptDismiss(sequence) {
    var nextSequence = Number(sequence)
    if (!isFinite(nextSequence) || nextSequence <= lastEventSequence) return
    lastEventSequence = nextSequence
    if (!superHeld) return
    consumed = true
    generation += 1
    revealTimer.stop()
    revealDue = false
    close()
  }

  function rebuildModel() {
    viewModel = Model.buildRows(bindings, modifierMask)
  }

  function maybeReveal() {
    opened = revealDue && superHeld && !consumed && config.maskEnabled(modifierMask) && bindingsReady
      && viewModel && viewModel.rows && viewModel.rows.length > 0
  }

  function requestBindings(requestGeneration) {
    if (!sourceDir) {
      console.warn("huacnlee.which-key: plugin source directory is unavailable")
      return
    }

    if (bindingProcess.running) {
      pendingLoadGeneration = requestGeneration
      bindingProcess.running = false
      return
    }
    startBindingLoad(requestGeneration)
  }

  function startBindingLoad(requestGeneration) {
    bindingProcess.loadGeneration = requestGeneration
    bindingProcess.command = [sourceDir + "/scripts/which-key-bindings"]
    bindingProcess.running = true
  }

  function acceptBindingOutput(requestGeneration, output) {
    if (!Model.isCurrentGeneration(generation, requestGeneration) || !superHeld)
      return

    var payload = String(output || "")
    if (Model.isPayloadTooLarge(payload)) {
      console.warn("huacnlee.which-key: binding data is too large; ignoring it")
      return
    }

    var parsed
    try {
      parsed = JSON.parse(payload)
    } catch (error) {
      console.warn("huacnlee.which-key: invalid binding data:", error)
      return
    }
    if (!Array.isArray(parsed)) return

    bindings = Model.limitBindings(parsed)
    bindingsReady = true
    rebuildModel()
    maybeReveal()
  }

  Timer {
    id: revealTimer
    interval: config.delayMs
    repeat: false
    onTriggered: {
      root.revealDue = true
      root.maybeReveal()
    }
  }

  Process {
    id: bindingProcess
    property int loadGeneration: 0
    command: []
    running: false
    stdout: StdioCollector { id: bindingStdout; waitForEnd: true }
    stderr: StdioCollector { id: bindingStderr; waitForEnd: true }

    onExited: function(exitCode, exitStatus) {
      var completedGeneration = loadGeneration
      var nextGeneration = root.pendingLoadGeneration
      root.pendingLoadGeneration = 0

      if (exitCode === 0)
        root.acceptBindingOutput(completedGeneration, bindingStdout.text)
      else if (Model.isCurrentGeneration(root.generation, completedGeneration)
          && root.superHeld && nextGeneration === 0)
        console.warn("huacnlee.which-key: binding load failed:", bindingStderr.text)

      if (nextGeneration !== 0)
        Qt.callLater(function() { root.startBindingLoad(nextGeneration) })
    }
  }

  IpcHandler {
    target: "huacnlee.which-key"

    function state(sequence: int, mask: int): void {
      root.acceptState(sequence, mask)
    }

    function dismiss(sequence: int): void {
      root.acceptDismiss(sequence)
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: overlay
      required property var modelData
      readonly property string screenName: modelData ? String(modelData.name) : ""

      screen: modelData
      visible: root.opened && screenName === root.focusedScreenName
      anchors { top: true; right: true; bottom: true; left: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "huacnlee-which-key"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      // The guide is visual only. An empty input region guarantees that the
      // held modifier and the next shortcut continue to reach the active app.
      mask: Region {}

      WhichKeyCard {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Style.gapsOut
        anchors.bottomMargin: Style.gapsOut
        viewModel: root.viewModel
        availableWidth: overlay.width - Style.gapsOut * 2
      }
    }
  }
}

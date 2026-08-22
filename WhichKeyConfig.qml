import QtQuick
import Quickshell
import Quickshell.Io
import "WhichKeySettings.js" as Settings

QtObject {
  id: root

  property int delayMs: 200
  property var enabledMasks: Settings.DEFAULT_MASKS.slice()
  property bool loaded: false
  property string error: ""

  readonly property string configHome: {
    var configured = Quickshell.env("XDG_CONFIG_HOME")
    return configured ? String(configured) : Quickshell.env("HOME") + "/.config"
  }
  readonly property string path: configHome + "/omarchy/which-key.json"
  readonly property var combinations: [
    { mask: 64, label: "SUPER" },
    { mask: 65, label: "SUPER + SHIFT" },
    { mask: 68, label: "SUPER + CTRL" },
    { mask: 72, label: "SUPER + ALT" },
    { mask: 69, label: "SUPER + SHIFT + CTRL" },
    { mask: 73, label: "SUPER + SHIFT + ALT" },
    { mask: 76, label: "SUPER + CTRL + ALT" },
    { mask: 77, label: "SUPER + SHIFT + CTRL + ALT" }
  ]

  function apply(raw) {
    var value = {}
    var text = String(raw || "")
    error = ""
    if (Settings.isOversized(text)) {
      error = "Settings file is too large; defaults are active."
    } else if (text.trim()) {
      try { value = JSON.parse(text) }
      catch (exception) { error = "Settings file is invalid; defaults are active." }
    }
    var normalized = Settings.normalize(value)
    delayMs = normalized.delayMs
    enabledMasks = normalized.enabledMasks
    loaded = true
  }

  function save() {
    settingsFile.setText(JSON.stringify({
      version: 1,
      delayMs: delayMs,
      enabledMasks: enabledMasks
    }, null, 2) + "\n")
  }

  function setDelay(value) {
    delayMs = Settings.normalize({ delayMs: value, enabledMasks: enabledMasks }).delayMs
    save()
  }

  function setMask(mask, enabled) {
    enabledMasks = Settings.toggleMask(enabledMasks, mask, enabled)
    save()
  }

  function selectAll() { enabledMasks = Settings.DEFAULT_MASKS.slice(); save() }
  function clearAll() { enabledMasks = []; save() }
  function maskEnabled(mask) { return Settings.maskEnabled(enabledMasks, mask) }

  property FileView settingsFile: FileView {
    path: root.path
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.apply(text())
    onLoadFailed: root.apply("")
    onFileChanged: reload()
  }

  Component.onCompleted: settingsFile.reload()
}

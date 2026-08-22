.pragma library

var MODIFIERS = [
  { bit: 64, label: "SUPER" },
  { bit: 1, label: "SHIFT" },
  { bit: 4, label: "CTRL" },
  { bit: 8, label: "ALT" }
]

var KEY_LABELS = {
  RETURN: "Enter",
  ENTER: "Enter",
  ESCAPE: "Esc",
  SPACE: "Space",
  TAB: "Tab",
  BACKSPACE: "Backspace",
  DELETE: "Delete",
  LEFT: "←",
  RIGHT: "→",
  UP: "↑",
  DOWN: "↓",
  HOME: "Home",
  END: "End",
  PAGEUP: "Page Up",
  PAGEDOWN: "Page Down"
}

// Hyprland exposes physical-code bindings as XKB keycodes (evdev code + 8).
// Convert the standard keyboard range so the guide never leaks `code:NN`.
var XKB_KEY_LABELS = {
  9: "Esc", 20: "-", 21: "=", 22: "Backspace", 23: "Tab",
  34: "[", 35: "]", 36: "Enter", 37: "Ctrl", 47: ";", 48: "'",
  49: "`", 50: "Shift", 51: "\\", 59: ",", 60: ".", 61: "/",
  62: "Shift", 63: "Num *", 64: "Alt", 65: "Space", 66: "Caps Lock",
  77: "Num Lock", 78: "Scroll Lock", 79: "Num 7", 80: "Num 8",
  81: "Num 9", 82: "Num -", 83: "Num 4", 84: "Num 5", 85: "Num 6",
  86: "Num +", 87: "Num 1", 88: "Num 2", 89: "Num 3", 90: "Num 0",
  91: "Num .", 104: "Num Enter", 105: "Ctrl", 106: "Num /",
  107: "Print Screen", 108: "Alt", 110: "Home", 111: "↑",
  112: "Page Up", 113: "←", 114: "→", 115: "End", 116: "↓",
  117: "Page Down", 118: "Insert", 119: "Delete", 127: "Pause",
  133: "Super", 134: "Super", 135: "Menu"
}

var LETTER_ROWS = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
var LETTER_STARTS = [24, 38, 52]
for (var letterRow = 0; letterRow < LETTER_ROWS.length; letterRow++)
  for (var letterIndex = 0; letterIndex < LETTER_ROWS[letterRow].length; letterIndex++)
    XKB_KEY_LABELS[LETTER_STARTS[letterRow] + letterIndex] = LETTER_ROWS[letterRow][letterIndex]
for (var numberCode = 10; numberCode <= 19; numberCode++)
  XKB_KEY_LABELS[numberCode] = numberCode === 19 ? "0" : String(numberCode - 9)
for (var functionCode = 67; functionCode <= 76; functionCode++)
  XKB_KEY_LABELS[functionCode] = "F" + String(functionCode - 66)
XKB_KEY_LABELS[95] = "F11"
XKB_KEY_LABELS[96] = "F12"

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function modifierTitle(mask) {
  var numericMask = Number(mask)
  if (!isFinite(numericMask) || numericMask < 0) numericMask = 0
  numericMask = Math.floor(numericMask)

  var labels = []
  var knownMask = 0
  for (var index = 0; index < MODIFIERS.length; index++) {
    var modifier = MODIFIERS[index]
    knownMask |= modifier.bit
    if ((numericMask & modifier.bit) !== 0) labels.push(modifier.label)
  }

  var unknown = numericMask & ~knownMask
  var bit = 1
  while (unknown > 0 && bit <= 1073741824) {
    if ((unknown & bit) !== 0) {
      labels.push("MOD" + bit)
      unknown &= ~bit
    }
    bit *= 2
  }

  return labels.length > 0 ? labels.join(" + ") : "NONE"
}

function keyLabel(key, keycode) {
  var raw = String(key || "").trim()
  if (!raw && Number(keycode) > 0) raw = "code:" + Number(keycode)
  if (!raw) return ""

  var upper = raw.toUpperCase()
  if (KEY_LABELS[upper]) return KEY_LABELS[upper]

  var codeMatch = /^code:(\d+)$/i.exec(raw)
  if (codeMatch) {
    var code = Number(codeMatch[1])
    return XKB_KEY_LABELS[code] || "Key " + code
  }

  var mouseMatch = /^mouse:(\d+)$/i.exec(raw)
  if (mouseMatch) {
    var button = Number(mouseMatch[1])
    if (button >= 272 && button <= 279) return "Mouse " + (button - 271)
  }

  return raw
}

function triggerKey(key) {
  var value = String(key || "").trim()
  var previous
  do {
    previous = value
    value = value.replace(/^(SUPER|SHIFT|CTRL|CONTROL|ALT)\s*\+\s*/i, "")
  } while (value !== previous)
  return value.trim()
}

function isSpecialKey(key) {
  return !/^[A-Za-z0-9]$/.test(String(key || ""))
}

function specialRank(row) {
  if (!row.special) return 0
  if (/^(code|mouse):/i.test(row.key)) return 2
  return 1
}

function compareRows(left, right) {
  var rankDifference = specialRank(left) - specialRank(right)
  if (rankDifference !== 0) return rankDifference

  return String(left.label).localeCompare(String(right.label), undefined, {
    numeric: true,
    sensitivity: "base"
  })
}

function chunkRows(rows, maximum) {
  var columns = []
  for (var index = 0; index < rows.length; index += maximum)
    columns.push(rows.slice(index, index + maximum))
  return columns
}

function buildRows(bindings, modifierMask, options) {
  var source = Array.isArray(bindings) ? bindings : []
  var numericMask = Number(modifierMask)
  var rows = []

  for (var index = 0; index < source.length; index++) {
    var binding = source[index]
    if (!isRecord(binding) || Number(binding.modmask) !== numericMask) continue

    var description = String(binding.description || "").trim()
    var key = triggerKey(binding.key)
    var label = keyLabel(key, binding.keycode)
    if (!description || !key || !label) continue

    rows.push({
      key: key,
      label: label,
      description: description,
      duplicate: false,
      special: isSpecialKey(key),
      keycode: Number(binding.keycode) || 0,
      submap: String(binding.submap || ""),
      release: binding.release === true,
      repeat: binding.repeat === true
    })
  }

  var counts = {}
  for (var countIndex = 0; countIndex < rows.length; countIndex++) {
    var identity = rows[countIndex].key.toUpperCase()
    counts[identity] = (counts[identity] || 0) + 1
  }
  for (var markIndex = 0; markIndex < rows.length; markIndex++)
    rows[markIndex].duplicate = counts[rows[markIndex].key.toUpperCase()] > 1

  var requestedMaximum = options && Number(options.maxRowsPerColumn)
  var maximum = isFinite(requestedMaximum) && requestedMaximum > 0
    ? Math.max(1, Math.floor(requestedMaximum))
    : 12

  return {
    title: modifierTitle(numericMask),
    rows: rows,
    columns: chunkRows(rows, maximum)
  }
}

function isCurrentGeneration(expected, received) {
  return expected === received
}

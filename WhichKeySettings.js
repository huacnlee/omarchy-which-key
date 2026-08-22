.pragma library

var DEFAULT_MASKS = [64, 65, 68, 72, 69, 73, 76, 77]

function normalize(value) {
  var source = value && typeof value === "object" ? value : {}
  var delay = Number(source.delayMs)
  if (!isFinite(delay)) delay = 200
  delay = Math.max(0, Math.min(1000, Math.round(delay / 50) * 50))

  var requested = Array.isArray(source.enabledMasks) ? source.enabledMasks : DEFAULT_MASKS
  var enabled = []
  for (var index = 0; index < DEFAULT_MASKS.length; index++) {
    var mask = DEFAULT_MASKS[index]
    if (requested.indexOf(mask) !== -1) enabled.push(mask)
  }
  return { delayMs: delay, enabledMasks: enabled }
}

function toggleMask(masks, mask, enabled) {
  var current = normalize({ enabledMasks: masks }).enabledMasks
  var next = []
  for (var index = 0; index < DEFAULT_MASKS.length; index++) {
    var candidate = DEFAULT_MASKS[index]
    if (candidate === Number(mask) ? enabled : current.indexOf(candidate) !== -1)
      next.push(candidate)
  }
  return next
}

function maskEnabled(masks, mask) {
  return normalize({ enabledMasks: masks }).enabledMasks.indexOf(Number(mask)) !== -1
}

const assert = require("assert")
const { load } = require("./load")
const Settings = load("WhichKeySettings.js")

const defaults = Settings.normalize()
assert.strictEqual(defaults.delayMs, 200)
assert.deepStrictEqual(Array.from(defaults.enabledMasks), [64, 65, 68, 72, 69, 73, 76, 77])

assert.strictEqual(Settings.normalize({ delayMs: -4 }).delayMs, 0)
assert.strictEqual(Settings.normalize({ delayMs: 1201 }).delayMs, 1000)
assert.strictEqual(Settings.normalize({ delayMs: 226 }).delayMs, 250)
assert.deepStrictEqual(Array.from(Settings.normalize({ enabledMasks: [72, 64, 72, 999] }).enabledMasks), [64, 72])
assert.deepStrictEqual(Array.from(Settings.toggleMask(defaults.enabledMasks, 64, false)), [65, 68, 72, 69, 73, 76, 77])
assert.strictEqual(Settings.maskEnabled([65], 65), true)
assert.strictEqual(Settings.maskEnabled([65], 64), false)

console.log("settings tests passed")

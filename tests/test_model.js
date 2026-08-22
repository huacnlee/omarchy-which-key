const assert = require("assert")
const { load } = require("./load")

const Model = load("WhichKeyModel.js")

const bindings = [
  { modmask: 65, key: "TAB", keycode: 0, description: "Previous workspace" },
  { modmask: 65, key: "B", keycode: 0, description: "Private browser" },
  { modmask: 65, key: "1", keycode: 0, description: "Move to workspace 1" },
  { modmask: 64, key: "W", keycode: 0, description: "Close window" },
  { modmask: 64, key: "B", keycode: 0, description: "Browser" },
  { modmask: 64, key: "B", keycode: 0, description: "Second browser", submap: "apps" },
  { modmask: 64, key: "Q", keycode: 0, description: "   " },
  { modmask: 68, key: "E", keycode: 0, description: "Emoji" },
  { modmask: 72, key: "mouse:272", keycode: 272, description: "Move window" },
  { modmask: 65, key: "code:20", keycode: 20, description: "Resize left" },
  null,
  "bad row"
]

const shifted = Model.buildRows(bindings, 65)
assert.deepStrictEqual(Array.from(shifted.rows, row => row.key), ["1", "B", "TAB", "code:20"])
assert.strictEqual(shifted.title, "SUPER + SHIFT")
assert.strictEqual(shifted.rows[2].label, "Tab")
assert.strictEqual(shifted.rows[3].label, "code:20")
assert.strictEqual(shifted.rows[3].special, true)

const superOnly = Model.buildRows(bindings, 64)
assert.deepStrictEqual(Array.from(superOnly.rows, row => row.key), ["B", "B", "W"])
assert.strictEqual(superOnly.rows[0].duplicate, true)
assert.strictEqual(superOnly.rows[1].duplicate, true)
assert.strictEqual(superOnly.rows[2].duplicate, false)
assert.strictEqual(superOnly.rows.some(row => row.key === "Q"), false)

const ctrl = Model.buildRows(bindings, 68)
assert.deepStrictEqual(Array.from(ctrl.rows, row => row.description), ["Emoji"])
assert.strictEqual(ctrl.title, "SUPER + CTRL")

const alt = Model.buildRows(bindings, 72)
assert.strictEqual(alt.rows[0].label, "Mouse 1")
assert.strictEqual(alt.title, "SUPER + ALT")

const columns = Model.buildRows(bindings, 65, { maxRowsPerColumn: 2 }).columns
assert.strictEqual(columns.length, 2)
assert.deepStrictEqual(Array.from(columns[0], row => row.key), ["1", "B"])
assert.deepStrictEqual(Array.from(columns[1], row => row.key), ["TAB", "code:20"])

assert.strictEqual(Model.buildRows(undefined, 64).rows.length, 0)
assert.strictEqual(Model.buildRows({}, 64).rows.length, 0)
assert.strictEqual(Model.buildRows([{ modmask: 64, key: "", description: "Broken" }], 64).rows.length, 0)

assert.strictEqual(Model.modifierTitle(77), "SUPER + SHIFT + CTRL + ALT")
assert.strictEqual(Model.modifierTitle(66), "SUPER + MOD2")
assert.strictEqual(Model.keyLabel("RETURN", 0), "Enter")
assert.strictEqual(Model.keyLabel("LEFT", 0), "←")
assert.strictEqual(Model.keyLabel("mystery-key", 0), "mystery-key")

assert.strictEqual(Model.isCurrentGeneration(3, 3), true)
assert.strictEqual(Model.isCurrentGeneration(3, 2), false)
assert.strictEqual(Model.isCurrentGeneration(3, "3"), false)

console.log("model tests passed")

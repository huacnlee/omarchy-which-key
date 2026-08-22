# Omarchy Which Key Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an Omarchy 4 overlay that shows the currently active, described Hyprland `Super` bindings in a LazyVim-style bottom-right card after Super is held for 200 ms.

**Architecture:** A minimal Hyprland Lua `input.keyboard.key` observer sends modifier press/release events to a keep-loaded, non-focusable Quickshell overlay. A short-lived parser reads `hyprctl binds` on every Super press, while a pure JavaScript model validates and filters the live result for the held modifier mask; QML owns only timing, placement, and themed presentation.

**Tech Stack:** Omarchy 4 plugin manifest, Quickshell/QML, JavaScript, Bash, Hyprland 0.56 Lua bindings, Node.js test runner, `jq`, `make`.

**Spec:** `docs/superpowers/specs/2026-08-22-omarchy-which-key-design.md`

## Global Constraints

- Hyprland runtime state is the only shortcut source; production files contain no copied shortcut table or invented description.
- The visible surface uses `WlrKeyboardFocus.None`, `ExclusionMode.Ignore`, and an empty input region.
- Existing Hyprland bindings remain compositor-owned and behave exactly as before installation.
- Reveal delay is exactly 200 ms.
- The plugin ID is `huacnlee.which-key` and the manifest uses `kind: overlay` with `keepLoaded: true`.
- Colors, spacing, typography, radius, and shadow come from Omarchy semantic theme tokens.
- Work in the current checkout; do not create a worktree.

## File Map

- `manifest.json` — Omarchy plugin identity and overlay entry point.
- `WhichKey.qml` — press-generation state machine, process lifecycle, IPC surface, and output instances.
- `WhichKeyModel.js` — pure validation, modifier filtering, labels, sorting, and columns.
- `components/WhichKeyCard.qml` — pointer-transparent themed card presentation.
- `components/OutputAnchor.qml` — focused-output selection and bottom-right placement.
- `scripts/which-key-bindings` — converts live plain `hyprctl binds` output to JSON.
- `scripts/which-key-trigger` — sends a single trigger event to the loaded plugin.
- `scripts/install-bindings` — idempotently installs the marked Lua hook with backup.
- `scripts/uninstall-bindings` — removes exactly the marked hook.
- `install.sh`, `uninstall.sh` — user-facing plugin lifecycle.
- `tests/fixtures/hyprctl-binds.txt` — parser-only compositor output fixture.
- `tests/test_bindings.sh` — parser behavior.
- `tests/test_model.js` — pure model behavior.
- `tests/test_install.sh` — reversible config mutation.
- `tests/test_source.sh` — manifest/QML safety and no production shortcut table.
- `Makefile` — `test`, `validate`, and `install` entry points.
- `README.md`, `LICENSE` — user and developer documentation.

---

### Task 1: Prove the passive Super trigger and reversible config seam

**Files:**
- Create: `scripts/which-key-trigger`
- Create: `scripts/install-bindings`
- Create: `scripts/uninstall-bindings`
- Create: `tests/test_install.sh`

**Interfaces:**
- Consumes: `OMARCHY_WHICH_KEY_HYPR_CONFIG` test override; defaults to `$HOME/.config/hypr/bindings.lua`.
- Produces: `which-key-trigger <press|release|modifiers> [mask]`; a marked Lua block bounded by `-- omarchy-which-key:begin` and `-- omarchy-which-key:end`.

- [ ] **Step 1: Write the failing installer test**

Create a temporary `bindings.lua`, run install twice, and assert one marked block, one timestamped backup, unchanged surrounding bytes, press/release commands, and no description strings. Run uninstall twice and assert exact restoration of the original file.

```bash
before_sha="$(sha256sum "$config" | cut -d' ' -f1)"
OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" scripts/install-bindings
OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" scripts/install-bindings
test "$(grep -c '^-- omarchy-which-key:begin$' "$config")" -eq 1
grep -q 'which-key-trigger press' "$config"
grep -q 'which-key-trigger release' "$config"
OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" scripts/uninstall-bindings
test "$(sha256sum "$config" | cut -d' ' -f1)" = "$before_sha"
```

- [ ] **Step 2: Run the test and verify RED**

Run: `bash tests/test_install.sh`

Expected: FAIL because lifecycle scripts do not exist.

- [ ] **Step 3: Implement minimal marked-block lifecycle**

The installed Lua uses `hl.on("input.keyboard.key", ...)`, with modifier keycodes read from `xkbcli compile-keymap` during installation. Both physical Super keys call the narrow trigger client, while Shift/Ctrl/Alt update its live modifier mask. The shell scripts resolve explicit paths, use `mktemp`, preserve file mode, and replace only the marked block.

The marked block contains one native event subscription and no `hl.bind(...)`
calls. Its callback ignores every keycode outside the eight detected physical
modifier keys.

`which-key-trigger` maps arguments to:

```bash
exec omarchy-shell huacnlee.which-key "$event" "$value"
```

- [ ] **Step 4: Run installer tests and static Lua checks**

Run: `bash tests/test_install.sh`

Expected: PASS. Also run `lua -e 'assert(loadfile(arg[1]))' "$fixture_config"` inside the test after installation.

- [ ] **Step 5: Perform the live safety gate**

Install the observer into the development config, run `hyprctl reload`, confirm `hyprctl configerrors` is empty, and compare representative `Super+1`, `Super+Shift+1`, `Super+W`, and one repeating/release binding with the pre-install baseline. If any binding changes, stop this plan and revise the approved design; do not continue with synthetic binds, evdev, or exclusive focus.

- [ ] **Step 6: Commit**

```bash
git add scripts/which-key-trigger scripts/install-bindings scripts/uninstall-bindings tests/test_install.sh
git commit -m "Add reversible Super trigger bridge"
```

---

### Task 2: Parse live Hyprland bindings without a shortcut registry

**Files:**
- Create: `scripts/which-key-bindings`
- Create: `tests/fixtures/hyprctl-binds.txt`
- Create: `tests/test_bindings.sh`

**Interfaces:**
- Consumes: plain `hyprctl binds` records or `OMARCHY_WHICH_KEY_HYPRCTL` fake command.
- Produces: JSON array of `{modmask,key,keycode,description,dispatcher,arg,release,repeat,submap}`; exit nonzero with no JSON on compositor failure.

- [ ] **Step 1: Write failing parser tests**

The fixture includes described and empty descriptions, Unicode, commas, quotes, a release binding, a repeat binding, a `code:20` key, and duplicate chords. Assertions use `jq -e` for exact fields and verify that no description is filtered by the parser.

```bash
json="$(OMARCHY_WHICH_KEY_HYPRCTL="$fake" scripts/which-key-bindings)"
jq -e 'length == 6' <<<"$json"
jq -e 'any(.[]; .description == "切换窗口")' <<<"$json"
jq -e 'any(.[]; .keycode == 20 and .repeat == true)' <<<"$json"
```

- [ ] **Step 2: Run the test and verify RED**

Run: `bash tests/test_bindings.sh`

Expected: FAIL because the parser does not exist.

- [ ] **Step 3: Implement a record parser**

Use `awk` to turn each `bind` block into unit-separator-delimited fields and `jq -Rn` to encode strings safely. Keep unknown fields empty, convert `true/false` to booleans, and never inspect Hyprland source files.

```bash
"$hyprctl_cmd" binds | awk '
  function emit() {
    if (!seen) return
    printf "%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n",
      field["modmask"], field["key"], field["keycode"],
      field["description"], field["dispatcher"], field["arg"],
      field["release"], field["repeat"], field["submap"]
  }
  /^bind/ { emit(); delete field; seen = 1; next }
  seen && match($0, /^\t[a-z]+: /) {
    field[substr($0, 2, RLENGTH - 3)] = substr($0, RLENGTH + 1)
  }
  END { emit() }
' |
  jq -Rn '[inputs | split("\u001f") | {
    modmask: (.[0] | tonumber), key: .[1], keycode: (.[2] | tonumber),
    description: .[3], dispatcher: .[4], arg: .[5],
    release: (.[6] == "true"), repeat: (.[7] == "true"), submap: .[8]
  }]'
```

- [ ] **Step 4: Run parser tests**

Run: `bash tests/test_bindings.sh`

Expected: PASS, including a fake `hyprctl` failure that produces a nonzero status.

- [ ] **Step 5: Commit**

```bash
git add scripts/which-key-bindings tests/fixtures/hyprctl-binds.txt tests/test_bindings.sh
git commit -m "Parse live Hyprland bindings"
```

---

### Task 3: Build the pure which-key model

**Files:**
- Create: `WhichKeyModel.js`
- Create: `tests/load.js`
- Create: `tests/test_model.js`

**Interfaces:**
- Consumes: `buildRows(bindings: unknown, modifierMask: number, options?: {maxRowsPerColumn?: number})`.
- Produces: `{title: string, rows: Array<{key,label,description,duplicate,special}>, columns: Array<Array<Row>>}` and `isCurrentGeneration(expected: number, received: number): boolean`.

- [ ] **Step 1: Write failing Node tests**

Cover SUPER mask 64; SUPER+SHIFT 65; CTRL 4 and ALT 8 filtering; empty-description removal; raw unknown key preservation; standard key labels; natural alphanumeric-before-special ordering; duplicate flags; malformed input; maximum rows per column; and generation equality.

```js
assert.deepEqual(Model.buildRows(bindings, 65).rows.map(row => row.key), ["1", "B", "TAB"])
assert.equal(Model.buildRows([{ modmask: 64, key: "Q", description: "" }], 64).rows.length, 0)
assert.equal(Model.isCurrentGeneration(3, 2), false)
```

- [ ] **Step 2: Run the tests and verify RED**

Run: `node tests/test_model.js`

Expected: FAIL because `WhichKeyModel.js` does not exist.

- [ ] **Step 3: Implement pure functions**

Export QML-compatible top-level functions and load them in Node through the existing `tests/load.js` VM pattern. Do not include any mapping descriptions or application-specific group rules.

```js
function buildRows(bindings, modifierMask, options) {
  var source = Array.isArray(bindings) ? bindings : []
  var rows = source.filter(function(binding) {
    return Number(binding.modmask) === Number(modifierMask)
      && String(binding.description || "").trim() !== ""
  }).map(toRow)
  return { title: modifierTitle(modifierMask), rows: sortAndMark(rows), columns: chunk(rows, maxRows) }
}
```

- [ ] **Step 4: Run model tests**

Run: `node tests/test_model.js`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WhichKeyModel.js tests/load.js tests/test_model.js
git commit -m "Add live binding presentation model"
```

---

### Task 4: Implement the non-focusable overlay state machine

**Files:**
- Create: `manifest.json`
- Create: `WhichKey.qml`
- Create: `tests/test_source.sh`

**Interfaces:**
- Consumes IPC methods `press(key: string)`, `release(key: string)`, and `modifiers(mask: int)` on target `huacnlee.which-key`.
- Produces properties `opened`, `generation`, `modifierMask`, `bindings`, and one `OutputAnchor` per screen.

- [ ] **Step 1: Write failing manifest/state source tests**

Assert schema version, overlay entry point, keep-loaded status, 200 ms timer, generation guards, live parser invocation, direct IPC methods, `WlrKeyboardFocus.None`, and absence of `Exclusive`, `OnDemand`, hard-coded shortcut descriptions, and command dispatch from binding data.

```bash
jq -e '.id == "huacnlee.which-key" and .keepLoaded == true and .entryPoints.overlay == "WhichKey.qml"' manifest.json
rg -q 'interval: 200' WhichKey.qml
! rg -q 'WlrKeyboardFocus\.(Exclusive|OnDemand)' WhichKey.qml components
```

- [ ] **Step 2: Run tests and verify RED**

Run: `bash tests/test_source.sh`

Expected: FAIL because the plugin files do not exist.

- [ ] **Step 3: Implement the manifest and state machine**

Use `Process` to start `scripts/which-key-bindings` at press time, increment `generation` on every press/release, and apply JSON only when the process generation matches. Start a 200 ms `Timer` concurrently and open only when at least one Super key remains held and rows exist.

```qml
IpcHandler {
  target: "huacnlee.which-key"
  function press(key: string): void { root.pressSuper(key) }
  function release(key: string): void { root.releaseSuper(key) }
  function modifiers(mask: int): void { root.setModifiers(mask) }
}
```

Render one output host through `Variants { model: Quickshell.screens }`, with visibility gated to the focused output reported by Hyprland.

- [ ] **Step 4: Run source and plugin validation**

Run: `bash tests/test_source.sh && omarchy plugin validate .`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add manifest.json WhichKey.qml tests/test_source.sh
git commit -m "Add passive which-key overlay state"
```

---

### Task 5: Render the LazyVim-style themed card and output anchor

**Files:**
- Create: `components/WhichKeyCard.qml`
- Create: `components/OutputAnchor.qml`
- Modify: `WhichKey.qml`
- Modify: `tests/test_source.sh`

**Interfaces:**
- Consumes: `WhichKeyCard.model` from `WhichKeyModel.buildRows`; `OutputAnchor.screen`, `opened`, and `model`.
- Produces: a bottom-right, clamped, pointer-transparent layer-shell card on the focused output.

- [ ] **Step 1: Extend source tests and verify RED**

Assert semantic `Color` and `Style` token usage; `WlrLayer.Overlay`; `WlrKeyboardFocus.None`; `ExclusionMode.Ignore`; empty `Region` input mask; bottom/right anchoring; no backdrop `MouseArea`; elided descriptions; dynamic columns; and no automatic animation.

```bash
rg -q 'anchors.*bottom' components/OutputAnchor.qml
rg -q 'WlrKeyboardFocus.None' components/OutputAnchor.qml
rg -q 'Text.ElideRight' components/WhichKeyCard.qml
! rg -q '#[0-9a-fA-F]{6,8}' components/WhichKeyCard.qml
```

- [ ] **Step 2: Implement token-driven card presentation**

Use `BorderSurface` with Omarchy `Color.popups.background`, `Color.popups.text`, `Color.popups.border`, `Style.font.*`, `Style.spacing.*`, `Style.cornerRadius`, and `Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))`. Lay out each column as a `Column`, each row as key, separator, and elided description; size the card from implicit content and clamp to the output minus `Style.gapsOut`. Do not install an automatic animation in the first version, so reduced-motion users and ordinary users share the same immediate lifecycle.

- [ ] **Step 3: Implement focused-output placement**

Use `Hyprland.focusedMonitor` to select the screen. The `PanelWindow` fills no more than its content bounds, anchors bottom/right with semantic margins, sets an empty input `Region`, and recomputes when screen geometry changes.

- [ ] **Step 4: Run tests and validate**

Run: `node tests/test_model.js && bash tests/test_source.sh && omarchy plugin validate .`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add components/WhichKeyCard.qml components/OutputAnchor.qml WhichKey.qml tests/test_source.sh
git commit -m "Render themed which-key popover"
```

---

### Task 6: Package, document, and verify the complete plugin

**Files:**
- Create: `install.sh`
- Create: `uninstall.sh`
- Create: `Makefile`
- Create: `README.md`
- Create: `LICENSE`
- Modify: `tests/test_install.sh`
- Modify: `tests/test_source.sh`

**Interfaces:**
- Consumes: repository root and installed Omarchy CLI.
- Produces: `make test`, `make validate`, `./install.sh`, and `./uninstall.sh` workflows.

- [ ] **Step 1: Add failing lifecycle and documentation assertions**

Test a temporary config root so install copies the repository to an Omarchy plugin directory, installs the marked hook, enables `huacnlee.which-key`, and uninstall removes only owned state. Assert README documents requirements, live-data behavior, install, uninstall, troubleshooting, and the explicit absence of built-in shortcut data.

- [ ] **Step 2: Run full tests and verify RED**

Run: `make test`

Expected: FAIL because packaging files do not exist.

- [ ] **Step 3: Implement lifecycle and documentation**

`install.sh` validates dependencies, delegates plugin installation to `omarchy plugin add` outside test mode, installs the hook, reloads Hyprland, checks `hyprctl configerrors`, and prints rollback guidance. `uninstall.sh` removes the hook before delegating to `omarchy plugin remove`. Both accept test-only path/command overrides without evaluating strings.

The README includes:

```text
Requirements -> Install -> How it works -> Usage -> Uninstall -> Development -> Troubleshooting
```

- [ ] **Step 4: Run automated verification**

Run: `make test && make validate && git diff --check`

Expected: all commands exit 0.

- [ ] **Step 5: Install into the live Omarchy session**

Run: `./install.sh`, then verify `omarchy plugin list --json` reports `huacnlee.which-key` enabled and `hyprctl configerrors` is empty.

- [ ] **Step 6: Complete live acceptance**

Record evidence for all nine acceptance cases in the spec: quick tap, 200 ms hold, modifier refinement, unchanged representative shortcut behavior, config reload freshness, both Super keys, multi-output placement, parser failure safety, and exact uninstall restoration. Reinstall after the uninstall test so the requested feature remains available.

- [ ] **Step 7: Run final verification and review**

Run: `make test && make validate && git status --short && git log --oneline --decorate -7`

Expected: tests and validation pass; status contains only intentional changes; history contains one focused commit per task.

- [ ] **Step 8: Commit**

```bash
git add install.sh uninstall.sh Makefile README.md LICENSE tests/test_install.sh tests/test_source.sh
git commit -m "Package Omarchy which-key plugin"
```

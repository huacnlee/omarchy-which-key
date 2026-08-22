# Omarchy Which Key Design

**Date:** 2026-08-22

## Goal

Build an Omarchy 4 shell plugin that treats `Super` as the desktop leader key.
Holding `Super` for 200 ms shows a compact which-key popover at the bottom-right
of the focused display. The popover describes the Hyprland bindings that are
actually active at that moment without taking focus or changing how Hyprland
executes them.

The interaction and information hierarchy follow `which-key.nvim`: delayed
reveal, concise key-to-description rows, live refinement as the key prefix
changes, and immediate dismissal when the prefix ends or an action is taken.
The visual reference is LazyVim's classic which-key popover rather than a
full-screen searchable shortcut table.

## Product Invariants

1. Hyprland is the only source of shortcut truth. The plugin contains no
   built-in shortcut list, copied command, inferred description, or parallel
   keymap configuration.
2. Existing shortcuts remain owned and executed by Hyprland. The plugin is an
   observer and presenter, never a shortcut dispatcher.
3. The visible overlay never requests keyboard focus and never installs a
   pointer hit target. A broken or missing plugin cannot prevent a shortcut
   from working.
4. A quick `Super` press shorter than 200 ms produces no visible UI.
5. Changes applied through a Hyprland config reload appear on the next reveal.
6. The plugin follows the active Omarchy theme and focused display. It does not
   ship a second theme system.

## User Experience

### Reveal and dismissal

- Pressing either physical Super key starts a 200 ms reveal timer.
- If Super is still held when the timer expires, the popover appears.
- Releasing the final held Super key dismisses the popover immediately.
- Releasing Super after an action dismisses the popover. If Hyprland exposes a
  passive compositor event for the action, the plugin may close earlier from
  that event, but it never binds or intercepts the action key to obtain it.
- Adding or removing `Shift`, `Ctrl`, or `Alt` while Super remains held updates
  the list for the current modifier chord.
- A press followed by release before the reveal delay cancels the timer and
  never maps the visible surface.

The first release does not close the popover when both Super keys are held. The
state closes only after neither Super key remains down.

### Content

Each row contains the remaining action key, an arrow separator, and the
description returned by Hyprland. The header shows the current chord, such as
`SUPER` or `SUPER + SHIFT`. A small footer explains that releasing Super closes
the panel.

Only bindings with a non-empty Hyprland description are visible. Unknown keys
are displayed using Hyprland's raw key name rather than guessed labels. If
multiple active bindings have the same chord, every described binding remains
visible and receives a duplicate indicator; the plugin does not claim which
dispatcher will win.

The initial version represents Hyprland's modifier chords. It does not invent
nested groups from command names or descriptions. A future Hyprland submap
adapter may expose real multi-stage prefixes, but only when that hierarchy can
also be read from live compositor state.

### Layout

The card is anchored to the bottom-right of the focused display and clamped to
the display's available geometry. It has no backdrop. Rows flow into columns
when vertical space is constrained, matching the dense LazyVim reference. Long
descriptions elide within a row; the plugin does not add an interactive tooltip
because the surface is intentionally pointer-transparent.

## Architecture

### Plugin host

The repository is an Omarchy third-party plugin with an `overlay` entry point
and `keepLoaded: true`. Keeping the QML object loaded avoids process startup on
the 200 ms path. The surface itself remains hidden and non-interactive until a
reveal is due.

`manifest.json` declares the overlay. `WhichKey.qml` composes the state,
loader, positioner, and presentation components and exposes narrow IPC methods
for trigger events. The plugin ID is `omarchy.which-key`.

### Trigger bridge

Installation adds a clearly marked, minimal block to the user's
`~/.config/hypr/bindings.lua`. It subscribes to Hyprland 0.56's native
`input.keyboard.key` Lua event and observes press/release for both Super keys
plus modifier-state changes while Super is held. XKB modifier keycodes are
resolved from the active compiled keymap at installation time rather than
assumed. The observer notifies the loaded plugin through `omarchy-shell` IPC.
It creates no key bindings, executes none of the user's shortcuts, and carries
no displayed shortcut metadata.

The trigger bridge must be proven not to change ordinary `Super+key` bindings
on the installed Hyprland version before the integration is considered
complete. It must not fall back to a synthetic key binding, `/dev/input`, root
access, or exclusive keyboard focus without a separately approved design
change.

The installer backs up the target file before editing it. The inserted block
has stable begin/end markers. Reinstall updates that block idempotently;
uninstall removes only that marked block. Packaged files under
`/usr/share/omarchy` are never modified.

### Binding loader

On Super press, a short-lived process requests current bindings from
`hyprctl binds`. The parser emits a stable JSON array with the compositor's
modifier mask, key/keycode, description, dispatcher, argument, release/repeat
flags, and submap where available. Dispatcher and argument are diagnostic
fields only and are never executed by the plugin.

The parser is deliberately source-agnostic: it consumes the compositor's
runtime output, including Omarchy defaults, user Lua bindings, generated
bindings, and runtime changes. It does not scan configuration source files.

The QML host begins the 200 ms timer and binding load concurrently. At expiry,
it reveals only when Super remains held and a valid result for the current
generation is ready. A late result from an earlier press is discarded using a
monotonic request generation. No cross-invocation shortcut cache is used, so
the next press always observes the current system.

### Model

`WhichKeyModel.js` is a pure transformation layer. It validates parsed rows,
normalizes modifier aliases and key labels, filters by the currently held
modifier mask, orders ordinary keys alphanumerically before special keys, and
calculates column layout input. It never manufactures descriptions or
commands.

Modifier state and visibility form a small deterministic state machine:

```text
idle -> pending -> visible -> idle
          |           |
          +-----------+  release/error
```

Every transition carries the current press generation so delayed timers and
process completions cannot reopen a dismissed popover.

### Presentation and placement

The presentation borrows the design principles documented in
`gpui-component`, translated to Omarchy QML rather than importing GPUI:

- lifecycle, placement, and presentation are separate components;
- colors use Omarchy semantic popover/surface, foreground, muted, border/ring,
  and accent tokens;
- spacing, typography, radius, and shadow derive from `Style` and theme tokens,
  never hard-coded product colors or literal corner radii;
- the application layer owns the card's visual composition while the state
  model remains presentation-free;
- the visible card has no focus, hover, active, selected, or disabled state
  because it is informational and pointer-transparent;
- placement is clamped to the focused output viewport and recomputed after an
  output geometry change;
- entrance/exit motion is presentation-owned, short, and disabled when reduced
  motion is requested. Logical close and keyboard ownership change immediately,
  even if a visual exit frame remains.

The surface uses `WlrKeyboardFocus.None`, `ExclusionMode.Ignore`, and an empty
input region. It is rendered on the overlay layer above normal windows without
reserving desktop space.

## Components and Files

```text
manifest.json
WhichKey.qml                 plugin composition and IPC surface
components/WhichKeyCard.qml presentation only
components/OutputAnchor.qml focused-output placement and clamping
WhichKeyModel.js             pure binding transformation
scripts/which-key-bindings   live hyprctl parser producing JSON
scripts/which-key-trigger    narrow IPC client for trigger hooks
scripts/install-bindings     idempotent marked-block installer
scripts/uninstall-bindings   marked-block removal
install.sh                   Omarchy plugin development install
uninstall.sh                 safe removal
tests/                       JS, shell, source, and fixture tests
```

No file in this tree contains a table of Omarchy shortcuts.

## Failure Handling

- If `hyprctl binds` fails, the current reveal is cancelled, existing shortcuts
  continue untouched, and one concise diagnostic is written to the plugin log.
- A malformed row is skipped independently. A malformed top-level response
  cancels that reveal.
- Empty results show no surface; they do not display stale data.
- Unknown modifier bits and key names remain visible in raw form.
- A trigger received while a load is active starts a newer generation and
  invalidates the old result.
- Output removal relocates the card to the newly focused available output or
  closes it when no output exists.
- Uninstall remains possible when the shell is not running and does not require
  IPC success.

## Testing

### Model tests

JavaScript tests cover modifier normalization, current-chord filtering,
ordering, duplicate preservation, unknown values, empty descriptions, malformed
rows, column calculation, and generation-based stale-result rejection. Fixtures
include representative plain-text `hyprctl binds` output from the installed
Hyprland version.

### Shell tests

Shell tests replace `hyprctl` and `omarchy-shell` with deterministic fakes and
cover valid JSON output, embedded punctuation and Unicode descriptions,
failure propagation, press/release/modifier IPC, idempotent installation,
backup creation, exact marked-block removal, and paths containing spaces.

A repository source test rejects shortcut-content fixtures outside the narrow
parser test data and ensures production code contains no built-in binding
descriptions.

### Plugin validation and QML checks

The repository must pass `omarchy plugin validate .`. QML components receive a
static load check where the installed toolchain permits it. Theme-token use,
non-focus configuration, empty input region, and overlay placement are covered
by source assertions where QML runtime introspection is unavailable.

### Live acceptance

On an Omarchy 4 / Hyprland 0.56 session:

1. Tap Super in less than 200 ms: no visible card.
2. Hold Super: card appears at the focused output's bottom-right around 200 ms.
3. Hold Super and press/release Shift, Ctrl, and Alt: rows reflect the current
   live chord.
4. Execute representative press, repeat, release, workspace, and application
   bindings: behavior matches the pre-install baseline and the card closes.
5. Change a described binding, reload Hyprland, and hold Super: the new key and
   description appear without plugin configuration.
6. Test both Super keys and the both-held release edge case.
7. Move focus between outputs and disconnect one: placement remains correct.
8. Force `hyprctl binds` failure: no stale card appears and shortcuts still
   work.
9. Uninstall: only plugin-owned files and the marked trigger block are removed;
   the user's surrounding Hyprland configuration remains byte-for-byte intact.

## Completion Criteria

The project is complete only when repository tests and Omarchy validation pass,
the live acceptance checks above have evidence, and the installed plugin meets
all product invariants. Passing parser tests alone does not prove that the
feature is safe: preservation of real Hyprland shortcut behavior and the
non-focus overlay must both be verified in a running session.

# Omarchy Which Key

A passive, theme-aware shortcut guide for Omarchy. Hold either Super key for
200 ms and the shortcuts currently registered in Hyprland appear at the bottom
right of the focused display.

## Requirements

Omarchy 4 with its Quickshell desktop, Hyprland Lua configuration support,
`hyprctl`, `xkbcli`, `jq`, and Node.js for development tests.

## Install

Clone this repository and run `./install.sh`. The installer validates and
enables the plugin, adds a marked keyboard-event observer to `bindings.lua`,
and reloads Hyprland. It never replaces existing bindings.

## How it works

The installer reads Hyprland's active keyboard model, layout, variant, and XKB
options, so remaps such as `altwin:swap_alt_win` still trigger the logical Super
modifier. The observer reports modifier state without registering a new
shortcut. The overlay then runs `hyprctl binds` each time Super is held and
filters those live results for the active modifier combination. It contains no built-in shortcut
information, so reloaded system changes appear on next use.
The full-screen layer has an empty input region and requests no keyboard focus.

## Usage

Hold a key mapped to Super for at least 200 ms. While it remains held, add Shift,
Ctrl, or Alt to switch to that exact modifier combination. The compact guide
shows at most ten results in one column. Release Super to close immediately.
A quick Super tap does not open the guide.

## Uninstall

Run `./uninstall.sh`. It removes only the marked observer and owned launcher,
then asks Omarchy to remove the plugin and reloads Hyprland.

## Development

Run `make test` for parser, model, source, hook, and lifecycle tests. Run
`make validate` for the Omarchy manifest validator and whitespace checks.

## Troubleshooting

If nothing appears, check `hyprctl configerrors`, confirm the plugin is enabled
with `omarchy plugin list --json`, and run `which-key-trigger press super_l`.
Bindings without a Hyprland description are intentionally omitted. Run the
uninstaller to restore the exact pre-install configuration around the owned
block.

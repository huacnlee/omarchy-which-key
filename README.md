# Omarchy Which Key

A passive, theme-aware shortcut guide for Omarchy. Hold either Super key for
200 ms and the shortcuts currently registered in Hyprland appear at the bottom
right of the focused display.

## Requirements

Omarchy 4 with its Quickshell desktop, Hyprland Lua configuration support,
`hyprctl`, `xkbcli`, `jq`, and Node.js for development tests.

## Install

Clone the repository and run the installer:

```bash
git clone https://github.com/huacnlee/omarchy-which-key.git
cd omarchy-which-key
./install.sh
```

The installer validates and enables `huacnlee.which-key`, creates
`~/.local/bin/which-key-trigger`, adds a marked keyboard-event observer to
`~/.config/hypr/bindings.lua`, and reloads Hyprland. It never replaces an
existing binding or an unrelated launcher.

To update an existing installation from the source checkout:

```bash
git pull
omarchy plugin update huacnlee.which-key --yes
~/.config/omarchy/plugins/huacnlee.which-key/scripts/install-bindings
hyprctl reload
omarchy-restart-shell
```

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
shows at most twenty results in one column. Release Super to close immediately.
A quick Super tap does not open the guide.

## Uninstall

From the cloned repository, run:

```bash
cd omarchy-which-key
./uninstall.sh
```

The uninstaller removes the marked observer block, removes the launcher only
when it points to this plugin, asks Omarchy to remove `huacnlee.which-key`, and
reloads Hyprland. Other bindings and files are left untouched. Keep the cloned
repository until after uninstalling so `./uninstall.sh` remains available.

## Development

Run `make test` for parser, model, source, hook, and lifecycle tests. Run
`make validate` for the Omarchy manifest validator and whitespace checks.

## Troubleshooting

If nothing appears, check `hyprctl configerrors` and confirm the plugin is
enabled with:

```bash
omarchy plugin list --json | jq '.[] | select(.id == "huacnlee.which-key")'
```

Bindings without a Hyprland description are intentionally omitted. Re-run the
installed `scripts/install-bindings` command after changing keyboard layout or
XKB options. Run the uninstaller to restore the exact pre-install configuration
around the owned block.

# Omarchy Which Key

Omarchy Which Key brings LazyVim's which-key experience to the desktop. It
automatically reads the active Omarchy and Hyprland keybindings and shows a
compact guide at the bottom right of the focused display when you hold Super.

<img width="250" alt="Omarchy Which-Key" src="preview.png" />

## Requirements

Omarchy 4 with its Quickshell desktop, Hyprland Lua configuration support,
`hyprctl`, `xkbcli`, `jq`, and Node.js for development tests.

## Install

Add and enable the plugin with Omarchy, then run its one-time system integration
setup:

```bash
omarchy plugin add https://github.com/huacnlee/omarchy-which-key.git --enable
~/.config/omarchy/plugins/huacnlee.which-key/install.sh
```

The first command uses Omarchy's standard plugin installation flow. The setup
script creates `~/.local/bin/which-key-trigger`, adds a marked keyboard-event
observer to `~/.config/hypr/bindings.lua`, and reloads Hyprland. It never
re-adds an already installed plugin, replaces an existing binding, or replaces
an unrelated launcher. Re-running the setup script safely refreshes the
observer after keyboard layout or XKB option changes.

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

Run the uninstaller from the installed plugin:

```bash
~/.config/omarchy/plugins/huacnlee.which-key/uninstall.sh
```

The uninstaller removes the marked observer block, removes the launcher only
when it points to this plugin, asks Omarchy to remove `huacnlee.which-key`, and
reloads Hyprland. Other bindings and files are left untouched.

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

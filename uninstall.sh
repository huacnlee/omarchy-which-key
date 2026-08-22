#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_id="huacnlee.which-key"
omarchy_command="${OMARCHY_WHICH_KEY_OMARCHY:-omarchy}"
hyprctl_command="${OMARCHY_WHICH_KEY_HYPRCTL:-hyprctl}"
plugin_dir="${OMARCHY_WHICH_KEY_TEST_PLUGIN_DIR:-${HOME}/.config/omarchy/plugins/${plugin_id}}"
trigger_link="${HOME}/.local/bin/which-key-trigger"

if [[ -x "$plugin_dir/scripts/uninstall-bindings" ]]; then
  "$plugin_dir/scripts/uninstall-bindings"
else
  "$repo_root/scripts/uninstall-bindings"
fi

if [[ -L "$trigger_link" && "$(readlink "$trigger_link")" == "$plugin_dir/scripts/which-key-trigger" ]]; then
  rm -- "$trigger_link"
fi

"$omarchy_command" plugin remove "$plugin_id" --yes
"$hyprctl_command" reload
printf 'Uninstalled %s and removed its owned Hyprland hook.\n' "$plugin_id"

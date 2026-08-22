#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_id="huacnlee.which-key"
omarchy_command="${OMARCHY_WHICH_KEY_OMARCHY:-omarchy}"
hyprctl_command="${OMARCHY_WHICH_KEY_HYPRCTL:-hyprctl}"
plugin_dir="${OMARCHY_WHICH_KEY_TEST_PLUGIN_DIR:-${HOME}/.config/omarchy/plugins/${plugin_id}}"
trigger_link="${HOME}/.local/bin/which-key-trigger"

if [[ -x "$plugin_dir/scripts/disable-integration" ]]; then
  "$plugin_dir/scripts/disable-integration"
else
  "$repo_root/scripts/disable-integration"
fi

"$omarchy_command" plugin remove "$plugin_id" --yes
printf 'Uninstalled %s and removed its owned Hyprland hook.\n' "$plugin_id"

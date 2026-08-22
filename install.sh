#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_id="huacnlee.which-key"
omarchy_command="${OMARCHY_WHICH_KEY_OMARCHY:-omarchy}"
hyprctl_command="${OMARCHY_WHICH_KEY_HYPRCTL:-hyprctl}"
plugin_dir="${OMARCHY_WHICH_KEY_TEST_PLUGIN_DIR:-${HOME}/.config/omarchy/plugins/${plugin_id}}"

for command_name in "$omarchy_command" "$hyprctl_command" jq xkbcli; do
  command -v "$command_name" >/dev/null || {
    printf 'omarchy-which-key: required command not found: %s\n' "$command_name" >&2
    exit 69
  }
done

"$omarchy_command" plugin validate "$repo_root"
if [[ ! -f "$plugin_dir/manifest.json" ]]; then
  "$omarchy_command" plugin add "$repo_root" --enable --yes
fi

"$plugin_dir/scripts/enable-integration"

printf 'Installed %s. Hold Super for 200 ms to show shortcuts.\n' "$plugin_id"
printf 'Rollback: %s/uninstall.sh\n' "$repo_root"

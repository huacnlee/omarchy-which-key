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

trigger_target="$plugin_dir/scripts/which-key-trigger"
bin_dir="${HOME}/.local/bin"
trigger_link="$bin_dir/which-key-trigger"
mkdir -p "$bin_dir"
if [[ -e "$trigger_link" || -L "$trigger_link" ]]; then
  if [[ ! -L "$trigger_link" || "$(readlink "$trigger_link")" != "$trigger_target" ]]; then
  printf 'omarchy-which-key: refusing to replace %s\n' "$trigger_link" >&2
  exit 73
  fi
fi
ln -sfn -- "$trigger_target" "$trigger_link"

"$plugin_dir/scripts/install-bindings"
"$hyprctl_command" reload
config_errors="$($hyprctl_command configerrors)"
if [[ -n "$config_errors" ]]; then
  printf 'omarchy-which-key: Hyprland reported configuration errors:\n%s\n' "$config_errors" >&2
  printf 'Run ./uninstall.sh to roll back the installed hook.\n' >&2
  exit 65
fi

printf 'Installed %s. Hold Super for 200 ms to show shortcuts.\n' "$plugin_id"
printf 'Rollback: %s/uninstall.sh\n' "$repo_root"

#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/bin" "$test_root/plugin" "$test_root/home/.config/hypr"
cp -a "$repo_root/." "$test_root/plugin/"
printf '%s\n' '-- existing' >"$test_root/home/.config/hypr/bindings.lua"

cat >"$test_root/bin/omarchy" <<'SH'
#!/bin/bash
printf 'omarchy %s\n' "$*" >>"$OMARCHY_WHICH_KEY_LIFECYCLE_LOG"
SH
cat >"$test_root/bin/hyprctl" <<'SH'
#!/bin/bash
printf 'hyprctl %s\n' "$*" >>"$OMARCHY_WHICH_KEY_LIFECYCLE_LOG"
if [[ ${1:-} == getoption ]]; then printf '%s\n' '{"str":""}'; exit 0; fi
[[ ${1:-} == configerrors ]] && printf '%s' ''
exit 0
SH
cat >"$test_root/bin/xkbcli" <<'SH'
#!/bin/bash
if [[ "$*" == *'--modmaps'* ]]; then
cat <<'MODMAPS'
Keys modifier maps:
  LFSH:
    real:    Shift
  RTSH:
    real:    Shift
  LCTL:
    real:    Control
  RCTL:
    real:    Control
  LALT:
    real:    Mod1
  RALT:
    real:    Mod1
  LWIN:
    real:    Mod4
  RWIN:
    real:    Mod4
MODMAPS
exit 0
fi
cat <<'MAP'
xkb_keycodes "evdev" {
  <LFSH> = 50;
  <RTSH> = 62;
  <LCTL> = 37;
  <RCTL> = 105;
  <LALT> = 64;
  <RALT> = 108;
  <LWIN> = 133;
  <RWIN> = 134;
};
MAP
SH
chmod +x "$test_root/bin/"*

export HOME="$test_root/home"
export PATH="$test_root/bin:$PATH"
export OMARCHY_WHICH_KEY_TEST_PLUGIN_DIR="$test_root/plugin"
export OMARCHY_WHICH_KEY_LIFECYCLE_LOG="$test_root/lifecycle.log"

"$test_root/plugin/install.sh"
if grep -Fq 'omarchy plugin add' "$OMARCHY_WHICH_KEY_LIFECYCLE_LOG"; then
  printf 'FAIL: installed plugin must not add itself again\n' >&2
  exit 1
fi
grep -Fq 'hyprctl reload' "$OMARCHY_WHICH_KEY_LIFECYCLE_LOG"
test -L "$HOME/.local/bin/which-key-trigger"
grep -Fq -- '-- omarchy-which-key:begin' "$HOME/.config/hypr/bindings.lua"

"$test_root/plugin/uninstall.sh"
grep -Fq 'omarchy plugin remove huacnlee.which-key --yes' "$OMARCHY_WHICH_KEY_LIFECYCLE_LOG"
test ! -e "$HOME/.local/bin/which-key-trigger"
test "$(cat "$HOME/.config/hypr/bindings.lua")" = '-- existing'

printf 'lifecycle tests passed\n'

#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

config="$test_root/bindings.lua"
shell_log="$test_root/shell.log"
fake_shell="$test_root/omarchy-shell"
fake_xkbcli="$test_root/xkbcli"
fake_hyprctl="$test_root/hyprctl"

assert_equal() {
  local expected="$1" actual="$2" message="$3"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_file_contains() {
  local file="$1" pattern="$2" message="$3"
  if ! grep -Fq -- "$pattern" "$file"; then
    printf 'FAIL: %s\nmissing: %s\n' "$message" "$pattern" >&2
    exit 1
  fi
}

cat >"$config" <<'LUA'
-- User bindings before which-key.
o.bind("SUPER + B", "Browser", "browser")
LUA
original_contents="$(<"$config")"
chmod 640 "$config"

cat >"$fake_shell" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$OMARCHY_WHICH_KEY_TEST_LOG"
SH
chmod +x "$fake_shell"

cat >"$fake_xkbcli" <<'SH'
#!/bin/bash
test "${1:-}" = compile-keymap
[[ "$*" == *'--options altwin:swap_alt_win'* ]]
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
    real:    Mod4
  RALT:
    real:    Mod4
  LWIN:
    real:    Mod1
  RWIN:
    real:    Mod1
MODMAPS
exit 0
fi
cat <<'KEYMAP'
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
KEYMAP
SH
chmod +x "$fake_xkbcli"

cat >"$fake_hyprctl" <<'SH'
#!/bin/bash
case "${3:-}" in
  input:kb_options) printf '%s\n' '{"str":"altwin:swap_alt_win"}' ;;
  *) printf '%s\n' '{"str":""}' ;;
esac
SH
chmod +x "$fake_hyprctl"

OMARCHY_WHICH_KEY_XKBCLI="$fake_xkbcli" \
OMARCHY_WHICH_KEY_HYPRCTL="$fake_hyprctl" \
OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" "$repo_root/scripts/install-bindings"

assert_equal "1" "$(grep -c '^-- omarchy-which-key:begin$' "$config")" \
  "installer should add one owned block"
test -f "${config}.omarchy-which-key.original"
assert_equal "final-newline" "$(<"${config}.omarchy-which-key.state")" \
  "first install should record the original file shape"
assert_equal "640" "$(stat -c '%a' "$config")" \
  "installer should preserve config mode"
assert_file_contains "$config" 'hl.on("input.keyboard.key"' \
  "installer should observe native keyboard events"
assert_file_contains "$config" 'which-key-trigger state " .. tostring(time)' \
  "observer should preserve compositor event order"
assert_file_contains "$config" 'which-key-trigger dismiss " .. tostring(time)' \
  "a non-modifier shortcut should dismiss the guide"
assert_file_contains "$config" '[64] = { name = "super_1", bit = 64 }' \
  "Super should follow the active XKB modifier map"
assert_file_contains "$config" '[108] = { name = "super_2", bit = 64 }' \
  "both configured Super keys should be observed"
assert_file_contains "$config" '[50] = { name = "shift_1", bit = 1 }' \
  "left Shift should update the modifier mask"
assert_file_contains "$config" '[37] = { name = "ctrl_1", bit = 4 }' \
  "left Ctrl should update the modifier mask"
assert_file_contains "$config" '[133] = { name = "alt_1", bit = 8 }' \
  "Alt should follow the active XKB modifier map"
if grep -Fq 'hl.bind(' "$config"; then
  printf 'FAIL: observer must not install a key binding\n' >&2
  exit 1
fi
assert_file_contains "$config" "$original_contents" \
  "installer should preserve surrounding user config"
OMARCHY_TEST_CONFIG="$config" \
  lua -e 'assert(loadfile(os.getenv("OMARCHY_TEST_CONFIG")))'

OMARCHY_WHICH_KEY_XKBCLI="$fake_xkbcli" \
OMARCHY_WHICH_KEY_HYPRCTL="$fake_hyprctl" \
OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" "$repo_root/scripts/install-bindings"

assert_equal "1" "$(grep -c '^-- omarchy-which-key:begin$' "$config")" \
  "reinstall should replace rather than duplicate the block"
test -f "${config}.omarchy-which-key.original"

OMARCHY_WHICH_KEY_SHELL="$fake_shell" \
OMARCHY_WHICH_KEY_TEST_LOG="$shell_log" \
  "$repo_root/scripts/which-key-trigger" state 1 64
OMARCHY_WHICH_KEY_SHELL="$fake_shell" \
OMARCHY_WHICH_KEY_TEST_LOG="$shell_log" \
  "$repo_root/scripts/which-key-trigger" state 2 65
OMARCHY_WHICH_KEY_SHELL="$fake_shell" \
OMARCHY_WHICH_KEY_TEST_LOG="$shell_log" \
  "$repo_root/scripts/which-key-trigger" dismiss 3

assert_equal $'huacnlee.which-key state 1 64\nhuacnlee.which-key state 2 65\nhuacnlee.which-key dismiss 3' \
  "$(<"$shell_log")" "trigger should forward exact IPC arguments"

if OMARCHY_WHICH_KEY_SHELL="$fake_shell" \
  OMARCHY_WHICH_KEY_TEST_LOG="$shell_log" \
  "$repo_root/scripts/which-key-trigger" invalid value 2>/dev/null; then
  printf 'FAIL: trigger should reject unknown events\n' >&2
  exit 1
fi

OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" "$repo_root/scripts/uninstall-bindings"
assert_equal "$original_contents" "$(<"$config")" \
  "uninstall should restore original config exactly"
test ! -e "${config}.omarchy-which-key.original"
test ! -e "${config}.omarchy-which-key.state"

OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" "$repo_root/scripts/uninstall-bindings"
assert_equal "$original_contents" "$(<"$config")" \
  "second uninstall should be a no-op"

printf 'install tests passed\n'

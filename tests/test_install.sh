#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

config="$test_root/bindings.lua"
shell_log="$test_root/shell.log"
fake_shell="$test_root/omarchy-shell"
fake_xkbcli="$test_root/xkbcli"

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

OMARCHY_WHICH_KEY_XKBCLI="$fake_xkbcli" \
OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" "$repo_root/scripts/install-bindings"

assert_equal "1" "$(grep -c '^-- omarchy-which-key:begin$' "$config")" \
  "installer should add one owned block"
assert_equal "1" "$(find "$test_root" -maxdepth 1 -name 'bindings.lua.bak.*' | wc -l)" \
  "first install should create one backup"
assert_equal "640" "$(stat -c '%a' "$config")" \
  "installer should preserve config mode"
assert_file_contains "$config" 'hl.on("input.keyboard.key"' \
  "installer should observe native keyboard events"
assert_file_contains "$config" '[133] = { name = "super_l", bit = 64 }' \
  "left Super should use the detected XKB keycode"
assert_file_contains "$config" '[134] = { name = "super_r", bit = 64 }' \
  "right Super should use the detected XKB keycode"
assert_file_contains "$config" '[50] = { name = "shift_l", bit = 1 }' \
  "left Shift should update the modifier mask"
assert_file_contains "$config" '[37] = { name = "ctrl_l", bit = 4 }' \
  "left Ctrl should update the modifier mask"
assert_file_contains "$config" '[64] = { name = "alt_l", bit = 8 }' \
  "left Alt should update the modifier mask"
if grep -Fq 'hl.bind(' "$config"; then
  printf 'FAIL: observer must not install a key binding\n' >&2
  exit 1
fi
assert_file_contains "$config" "$original_contents" \
  "installer should preserve surrounding user config"
OMARCHY_TEST_CONFIG="$config" \
  lua -e 'assert(loadfile(os.getenv("OMARCHY_TEST_CONFIG")))'

OMARCHY_WHICH_KEY_XKBCLI="$fake_xkbcli" \
OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" "$repo_root/scripts/install-bindings"

assert_equal "1" "$(grep -c '^-- omarchy-which-key:begin$' "$config")" \
  "reinstall should replace rather than duplicate the block"
assert_equal "1" "$(find "$test_root" -maxdepth 1 -name 'bindings.lua.bak.*' | wc -l)" \
  "reinstall should not create another backup"

OMARCHY_WHICH_KEY_SHELL="$fake_shell" \
OMARCHY_WHICH_KEY_TEST_LOG="$shell_log" \
  "$repo_root/scripts/which-key-trigger" press super_l
OMARCHY_WHICH_KEY_SHELL="$fake_shell" \
OMARCHY_WHICH_KEY_TEST_LOG="$shell_log" \
  "$repo_root/scripts/which-key-trigger" modifiers 65
OMARCHY_WHICH_KEY_SHELL="$fake_shell" \
OMARCHY_WHICH_KEY_TEST_LOG="$shell_log" \
  "$repo_root/scripts/which-key-trigger" release super_l

assert_equal $'huacnlee.which-key press super_l\nhuacnlee.which-key modifiers 65\nhuacnlee.which-key release super_l' \
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

OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" "$repo_root/scripts/uninstall-bindings"
assert_equal "$original_contents" "$(<"$config")" \
  "second uninstall should be a no-op"

printf 'install tests passed\n'

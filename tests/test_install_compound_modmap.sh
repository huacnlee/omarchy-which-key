#!/bin/bash

# Regression test: a key that carries more than one real modifier must still be
# observed. Omarchy's default kb_options include shift:both_capslock_cancel,
# which maps Left Shift to both Shift and Lock, so xkbcli reports
# "real: Shift + Lock" for LFSH. An exact single-modifier match drops that key
# and Super + Left Shift never updates the modifier mask.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

config="$test_root/bindings.lua"
fake_xkbcli="$test_root/xkbcli"
fake_hyprctl="$test_root/hyprctl"

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

cat >"$fake_xkbcli" <<'SH'
#!/bin/bash
test "${1:-}" = compile-keymap
if [[ "$*" == *'--modmaps'* ]]; then
cat <<'MODMAPS'
Keys modifier maps:
  LFSH:
    real:    Shift + Lock
    virtual: 0
  RTSH:
    real:    Shift
    virtual: 0
  LCTL:
    real:    Control
    virtual: 0
  LALT:
    real:    Mod1
    virtual: Alt
  LWIN:
    real:    Mod4
    virtual: Super
MODMAPS
exit 0
fi
cat <<'KEYMAP'
xkb_keycodes "evdev" {
  <LFSH> = 50;
  <RTSH> = 62;
  <LCTL> = 37;
  <LALT> = 64;
  <LWIN> = 133;
};
KEYMAP
SH
chmod +x "$fake_xkbcli"

cat >"$fake_hyprctl" <<'SH'
#!/bin/bash
case "${3:-}" in
  input:kb_options) printf '%s\n' '{"str":"compose:caps,shift:both_capslock_cancel"}' ;;
  *) printf '%s\n' '{"str":""}' ;;
esac
SH
chmod +x "$fake_hyprctl"

OMARCHY_WHICH_KEY_XKBCLI="$fake_xkbcli" \
OMARCHY_WHICH_KEY_HYPRCTL="$fake_hyprctl" \
OMARCHY_WHICH_KEY_HYPR_CONFIG="$config" "$repo_root/scripts/install-bindings"

assert_file_contains "$config" '[50] = { name = "shift_1", bit = 1 }' \
  "Left Shift mapped to Shift + Lock should still update the modifier mask"
assert_file_contains "$config" '[62] = { name = "shift_2", bit = 1 }' \
  "Right Shift should keep being observed alongside it"
assert_file_contains "$config" '[37] = { name = "ctrl_1", bit = 4 }' \
  "single-modifier keys should be unaffected by compound handling"
assert_file_contains "$config" '[64] = { name = "alt_1", bit = 8 }' \
  "Alt should follow the active XKB modifier map"
assert_file_contains "$config" '[133] = { name = "super_1", bit = 64 }' \
  "Super should follow the active XKB modifier map"

if grep -Fq 'name = "lock' "$config"; then
  printf 'FAIL: Lock is not a tracked modifier and must not be emitted\n' >&2
  exit 1
fi

OMARCHY_TEST_CONFIG="$config" \
  lua -e 'assert(loadfile(os.getenv("OMARCHY_TEST_CONFIG")))'

printf 'test_install_compound_modmap: ok\n'

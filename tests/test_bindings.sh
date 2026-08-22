#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_hyprctl="$test_root/hyprctl"
failure_hyprctl="$test_root/hyprctl-failure"

cat >"$fake_hyprctl" <<'SH'
#!/bin/bash
test "${1:-}" = binds
exec sed -n '1,$p' "$OMARCHY_WHICH_KEY_FIXTURE"
SH
chmod +x "$fake_hyprctl"

cat >"$failure_hyprctl" <<'SH'
#!/bin/bash
printf 'compositor unavailable\n' >&2
exit 7
SH
chmod +x "$failure_hyprctl"

json="$(
  OMARCHY_WHICH_KEY_HYPRCTL="$fake_hyprctl" \
  OMARCHY_WHICH_KEY_FIXTURE="$repo_root/tests/fixtures/hyprctl-binds.txt" \
    "$repo_root/scripts/which-key-bindings"
)"

jq -e 'length == 6' <<<"$json" >/dev/null
jq -e 'any(.[]; .description == "切换窗口" and .release == true)' <<<"$json" >/dev/null
jq -e 'any(.[]; .key == "code:20" and .keycode == 20 and .repeat == true)' <<<"$json" >/dev/null
jq -e 'any(.[]; .description == "Resize \"left\", precisely")' <<<"$json" >/dev/null
jq -e 'any(.[]; .description == "" and .arg == "hidden-in-model")' <<<"$json" >/dev/null
jq -e '[.[] | select(.modmask == 64 and .key == "B")] | length == 2' <<<"$json" >/dev/null
jq -e 'any(.[]; .submap == "resize")' <<<"$json" >/dev/null
jq -e 'any(.[]; .key == "mouse:272" and .arg == "")' <<<"$json" >/dev/null

big_fixture="$test_root/big-binds.txt"
for index in $(seq 1 3000); do
  printf 'bind\n\tmodmask: 64\n\tsubmap: \n\tkey: F%s\n\tkeycode: 0\n\tdescription: Bind %s\n\tdispatcher: exec\n\targ: true\n\trelease: false\n\trepeat: false\n' "$index" "$index"
done >"$big_fixture"

capped="$(
  OMARCHY_WHICH_KEY_HYPRCTL="$fake_hyprctl" \
  OMARCHY_WHICH_KEY_FIXTURE="$big_fixture" \
    "$repo_root/scripts/which-key-bindings"
)"
jq -e 'length == 2000' <<<"$capped" >/dev/null

records_capped="$(
  OMARCHY_WHICH_KEY_HYPRCTL="$fake_hyprctl" \
  OMARCHY_WHICH_KEY_FIXTURE="$repo_root/tests/fixtures/hyprctl-binds.txt" \
  OMARCHY_WHICH_KEY_MAX_BINDS=3 \
    "$repo_root/scripts/which-key-bindings"
)"
jq -e 'length == 3' <<<"$records_capped" >/dev/null

clipped="$(
  OMARCHY_WHICH_KEY_HYPRCTL="$fake_hyprctl" \
  OMARCHY_WHICH_KEY_FIXTURE="$repo_root/tests/fixtures/hyprctl-binds.txt" \
  OMARCHY_WHICH_KEY_MAX_FIELD=4 \
    "$repo_root/scripts/which-key-bindings"
)"
jq -e 'all(.[]; (.description | length) <= 4 and (.arg | length) <= 4 and (.key | length) <= 4)' <<<"$clipped" >/dev/null
jq -e 'any(.[]; .description == "切换窗口")' <<<"$clipped" >/dev/null

huge_fixture="$test_root/huge-binds.txt"
{
  printf 'bind\n\tmodmask: 64\n\tsubmap: \n\tkey: B\n\tkeycode: 0\n\tdescription: Browser\n\tdispatcher: exec\n\targ: true\n\trelease: false\n\trepeat: false\n'
  printf 'bind\n\tmodmask: 64\n\tsubmap: \n\tkey: C\n\tkeycode: 0\n\tdescription: '
  head -c 4194304 /dev/zero | tr '\0' 'x'
  printf '\n\tdispatcher: exec\n\targ: true\n\trelease: false\n\trepeat: false\n'
} >"$huge_fixture"

bounded="$(
  OMARCHY_WHICH_KEY_HYPRCTL="$fake_hyprctl" \
  OMARCHY_WHICH_KEY_FIXTURE="$huge_fixture" \
    "$repo_root/scripts/which-key-bindings"
)"
test "${#bounded}" -le 1048576
jq -e 'type == "array"' <<<"$bounded" >/dev/null
jq -e 'all(.[]; (.description | length) <= 512)' <<<"$bounded" >/dev/null
jq -e 'any(.[]; .description == "Browser")' <<<"$bounded" >/dev/null

if OMARCHY_WHICH_KEY_HYPRCTL="$failure_hyprctl" \
  "$repo_root/scripts/which-key-bindings" >"$test_root/failure.out" 2>"$test_root/failure.err"; then
  printf 'FAIL: parser should propagate hyprctl failure\n' >&2
  exit 1
fi

test ! -s "$test_root/failure.out"
grep -Fq 'compositor unavailable' "$test_root/failure.err"

printf 'binding parser tests passed\n'

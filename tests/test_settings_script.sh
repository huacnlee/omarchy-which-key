#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo_root/scripts/which-key-settings"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

assert_equal() {
  local expected="$1" actual="$2" message="$3"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

settings="$test_root/which-key.json"
out="$test_root/out"
err="$test_root/err"

read_settings() {
  OMARCHY_WHICH_KEY_SETTINGS="$1" timeout 10 "$helper" read >"$out" 2>"$err"
}

# A fresh install has no settings file at all; that is the default case, not a
# fault, so it reads as nothing and succeeds.
read_settings "$settings" || fail "a missing settings file should read as empty"
assert_equal "" "$(<"$out")" "a missing settings file should produce no output"

printf '{"delayMs":300}\n' >"$settings"
read_settings "$settings" || fail "a regular settings file should read"
assert_equal '{"delayMs":300}' "$(<"$out")" "settings should read back verbatim"

# A file that exactly fills the ceiling is still valid input.
printf '%s' '0123456789abcdef' >"$settings"
OMARCHY_WHICH_KEY_SETTINGS="$settings" OMARCHY_WHICH_KEY_SETTINGS_MAX_BYTES=16 \
  timeout 10 "$helper" read >"$out" 2>"$err" || fail "a file at the ceiling should read"
assert_equal "0123456789abcdef" "$(<"$out")" "a file at the ceiling should read whole"

# One byte past the ceiling is refused outright: the overlay never receives a
# half-read document it would only fail to parse.
printf '%s' '0123456789abcdefg' >"$settings"
if OMARCHY_WHICH_KEY_SETTINGS="$settings" OMARCHY_WHICH_KEY_SETTINGS_MAX_BYTES=16 \
  timeout 10 "$helper" read >"$out" 2>"$err"; then
  fail "a file past the ceiling should be refused"
fi
assert_equal "" "$(<"$out")" "a refused read should produce no output"
grep -Fq 'larger than' "$err" || fail "an oversized file should say so on stderr"

head -c 200000 /dev/zero | tr '\0' 'a' >"$settings"
if read_settings "$settings"; then
  fail "the default ceiling should refuse a 200 kB settings file"
fi
assert_equal "" "$(<"$out")" "a refused read should produce no output"

# A symlink at the settings path must not redirect the read somewhere else.
printf '{"delayMs":900}\n' >"$test_root/elsewhere.json"
ln -sf "$test_root/elsewhere.json" "$test_root/link.json"
if read_settings "$test_root/link.json"; then
  fail "a symlinked settings path should be refused"
fi
assert_equal "" "$(<"$out")" "a symlinked settings path should produce no output"
grep -Fq 'regular file' "$err" || fail "a symlink should be reported as a file type problem"

# A FIFO must neither block the read nor be treated as settings.
mkfifo "$test_root/fifo.json"
read_status=0
read_settings "$test_root/fifo.json" || read_status=$?
test "$read_status" -ne 124 || fail "a FIFO settings path must not block the read"
test "$read_status" -ne 0 || fail "a FIFO settings path should be refused"
assert_equal "" "$(<"$out")" "a FIFO settings path should produce no output"

# A directory is not settings either.
mkdir -p "$test_root/dir.json"
if read_settings "$test_root/dir.json"; then
  fail "a directory settings path should be refused"
fi

# Writing owns the whole document, including the parent directory on a fresh
# install, and lands atomically.
target="$test_root/fresh/which-key.json"
OMARCHY_WHICH_KEY_SETTINGS="$target" "$helper" write 250 "64,72"
jq -e '.version == 1 and .delayMs == 250 and .enabledMasks == [64, 72]' "$target" >/dev/null \
  || fail "write should store the requested settings"

OMARCHY_WHICH_KEY_SETTINGS="$target" "$helper" write 0 ""
jq -e '.delayMs == 0 and .enabledMasks == []' "$target" >/dev/null \
  || fail "write should store an empty selection"
assert_equal "" "$(find "$(dirname "$target")" -name '.which-key*' -print)" \
  "write should leave no temporary file behind"

if OMARCHY_WHICH_KEY_SETTINGS="$target" "$helper" write abc "64" 2>/dev/null; then
  fail "write should reject a non-numeric delay"
fi
if OMARCHY_WHICH_KEY_SETTINGS="$target" "$helper" write 200 "64;rm -rf /" 2>/dev/null; then
  fail "write should reject a malformed mask list"
fi
jq -e '.delayMs == 0 and .enabledMasks == []' "$target" >/dev/null \
  || fail "a rejected write should leave the stored settings untouched"

if OMARCHY_WHICH_KEY_SETTINGS="$target" "$helper" nonsense 2>/dev/null; then
  fail "an unknown command should be rejected"
fi
if OMARCHY_WHICH_KEY_SETTINGS="$target" OMARCHY_WHICH_KEY_SETTINGS_MAX_BYTES=0 \
  "$helper" read 2>/dev/null; then
  fail "a zero ceiling should be rejected"
fi

printf 'settings script tests passed\n'

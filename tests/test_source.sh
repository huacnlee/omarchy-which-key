#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

jq -e '
  .schemaVersion == 1
  and .id == "huacnlee.which-key"
  and .kinds == ["overlay"]
  and .keepLoaded == true
  and .entryPoints.overlay == "WhichKey.qml"
' manifest.json >/dev/null

grep -Fq 'interval: 200' WhichKey.qml
grep -Fq 'target: "huacnlee.which-key"' WhichKey.qml
grep -Fq 'model: Quickshell.screens' WhichKey.qml
grep -Fq 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.None' WhichKey.qml
grep -Fq 'exclusionMode: ExclusionMode.Ignore' WhichKey.qml
grep -Fq 'mask: Region {}' WhichKey.qml
grep -Fq 'screenName === root.focusedScreenName' WhichKey.qml

test -f components/WhichKeyCard.qml
grep -Fq 'Color.popups.background' components/WhichKeyCard.qml
grep -Fq 'Color.popups.border' components/WhichKeyCard.qml
grep -Fq 'Style.cornerRadius' components/WhichKeyCard.qml
grep -Fq 'modelData.description' components/WhichKeyCard.qml
grep -Fq 'modelData.label' components/WhichKeyCard.qml

for file in README.md LICENSE Makefile install.sh uninstall.sh; do
  test -f "$file"
done
for heading in Requirements Install 'How it works' Usage Uninstall Development Troubleshooting; do
  grep -Fq "## $heading" README.md
done
grep -Fqi 'no built-in shortcut' README.md
grep -Fq 'function state(sequence: int, mask: int)' WhichKey.qml
grep -Fq 'nextSequence <= lastEventSequence' WhichKey.qml
grep -Fq 'viewModel.rows.slice(0, 10)' components/WhichKeyCard.qml
grep -Fq 'scripts/which-key-bindings' WhichKey.qml
grep -Fq 'loadGeneration' WhichKey.qml
grep -Fq 'Model.isCurrentGeneration' WhichKey.qml

if grep -Eq 'WlrKeyboardFocus\.(Exclusive|OnDemand)' WhichKey.qml; then
  printf 'FAIL: overlay state must never request keyboard focus\n' >&2
  exit 1
fi

if grep -Eq 'binding\.(dispatcher|arg)|execDetached\([^)]*(dispatcher|arg)' WhichKey.qml; then
  printf 'FAIL: overlay must never dispatch commands from binding data\n' >&2
  exit 1
fi

printf 'source tests passed\n'

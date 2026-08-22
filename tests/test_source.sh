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
jq -e '.description == "A LazyVim which-key-style shortcut guide that automatically reads Omarchy live keybindings and appears when you hold Super"' manifest.json >/dev/null

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
grep -Fq 'git clone https://github.com/huacnlee/omarchy-which-key.git' README.md
grep -Fq 'alt="Omarchy Which-Key"' README.md
grep -Fq 'src="preview.png"' README.md
grep -Fq "Omarchy Which Key brings LazyVim's which-key experience to the desktop." README.md
test -f preview.png
grep -Fq './install.sh' README.md
grep -Fq './uninstall.sh' README.md
grep -Fq 'omarchy plugin update huacnlee.which-key --yes' README.md
if grep -Fq 'which-key-trigger press' README.md; then
  printf 'FAIL: README must not document the retired trigger protocol\n' >&2
  exit 1
fi
grep -Fq 'function state(sequence: int, mask: int)' WhichKey.qml
grep -Fq 'function dismiss(sequence: int)' WhichKey.qml
grep -Fq '!consumed' WhichKey.qml
grep -Fq 'nextSequence <= lastEventSequence' WhichKey.qml
grep -Fq 'viewModel.rows.slice(0, 20)' components/WhichKeyCard.qml
grep -Fq 'readonly property int pad: Style.space(10)' components/WhichKeyCard.qml
grep -Fq 'readonly property int rowGap: Style.space(4)' components/WhichKeyCard.qml
grep -Fq 'availableWidth, Style.space(380)' components/WhichKeyCard.qml
grep -Fq 'color: Color.accent' components/WhichKeyCard.qml
grep -Fq 'text: "Backspace"' components/WhichKeyCard.qml
grep -Fq 'Math.ceil(keyMetrics.advanceWidth)' components/WhichKeyCard.qml
grep -Fq 'font.weight: Font.Normal' components/WhichKeyCard.qml
test "$(grep -Fc 'color: Color.muted' components/WhichKeyCard.qml)" -eq 1
if grep -Eq '#[0-9A-Fa-f]{3,8}|Qt\.rgba?\(|color:[[:space:]]*"[^"]+"' components/WhichKeyCard.qml; then
  printf 'FAIL: visible card colors must use Omarchy system color tokens\n' >&2
  exit 1
fi
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

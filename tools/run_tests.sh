#!/bin/sh
# Portable runner used by Git hooks and CI.

set -u

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ -n "${GODOT_BIN:-}" ]; then
  godot_bin=$GODOT_BIN
elif command -v godot >/dev/null 2>&1; then
  godot_bin=godot
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin=godot4
else
  echo "Godot was not found. Set GODOT_BIN or add godot/godot4 to PATH." >&2
  exit 1
fi

output_file=$(mktemp "${TMPDIR:-/tmp}/lost-signal-tests.XXXXXX") || exit 1
trap 'rm -f "$output_file"' EXIT HUP INT TERM

"$godot_bin" --headless --path "$repo_root" --script res://tools/tests/run_tests.gd >"$output_file" 2>&1
exit_code=$?
cat "$output_file"

if [ "$exit_code" -ne 0 ]; then
  exit "$exit_code"
fi

if grep -Eq 'SCRIPT ERROR:|Failed to load script|CrashHandlerException|\[FAIL\]|Some tests failed\.' "$output_file"; then
  echo "Godot reported a fatal script error." >&2
  exit 1
fi

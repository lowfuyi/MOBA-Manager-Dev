#!/usr/bin/env bash
# Run every check. Usage: tools/run_all_checks.sh [path-to-godot-binary]
# Godot is optional; without it the GDScript tests are skipped and reported as skipped.
set -u
cd "$(dirname "$0")/.."
fail=0
python3 tools/validate_data.py || fail=1
python3 tools/check_strings.py || fail=1
python3 -m pytest -q tools || fail=1
python3 -I tools/calibrate.py 40000 --check || fail=1
G="${1:-${GODOT:-}}"
if [ -n "$G" ] && [ -x "$G" ]; then
  (cd game && "$G" --headless --import >/dev/null 2>&1; "$G" --headless --script res://tests/run_tests.gd) || fail=1
else
  echo "SKIPPED: GDScript tests (no Godot binary given)"
fi
exit $fail

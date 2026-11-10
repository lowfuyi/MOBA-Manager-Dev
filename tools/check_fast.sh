#!/usr/bin/env bash
# Fast check loop (build plan 3.3). Run after every change. Usage: tools/check_fast.sh [path-to-godot-binary]
# Godot binary: first argument or $GODOT (required). About 2 to 3 minutes. The full 25-minute check is
# tools/run_all_checks.sh. Renderer-only checks (perf gate, screenshots) are NOT here: they need Xvfb.
#   1 validate_data.py, check_strings.py (0 unknown keys), pytest tools (tools/test_*.py)
#   2 godot --headless --import (new class_name files)
#   3 run_tests.gd: logic, golden vectors, string and data tests, every tests/*_tests.gd (this includes
#     perf_gate_tests.gd: the perf allowance logic and tests/perf_allowances.json; the probe itself needs Xvfb)
#   4 ui_smoke.tscn, then every tests/check_*.tscn (each ends " N checks, 0 failures", no engine errors)
#   5 touch scenes (ui_touch.tscn and every tests/check_touch_*.tscn) with override.cfg present, then removed
#   6 golden vectors: sha256 of game/tests/golden/* equals the value recorded below (src/sim and sim data
#     must not change in 0.7, build plan R3). To change it on purpose, the Lead Programmer edits the value.
set -u
cd "$(dirname "$0")/.."
# sha256 over "<sha256>  <name>" lines of the files in game/tests/golden, sorted by name (LC_ALL=C). Recorded 2026-11-09 (I-00).
GOLDEN_SHA256=0b81a41be2144263c06c2b54c047ceb1c743314ba0400016ab7d87218888ee3c

G="${1:-${GODOT:-}}"
if [ -z "$G" ] || [ ! -x "$G" ]; then
  echo "check_fast: no Godot binary (pass it as the first argument or set GODOT)"; exit 2
fi
fail=0
results=()
note() { results+=("$1"); }

step() {  # step <label> <command...>: passes when the command exits 0
  local label="$1"; shift
  local t0=$SECONDS
  if "$@" >/tmp/check_fast_step.$$ 2>&1; then note "PASS  $label ($((SECONDS - t0)) s)"
  else note "FAIL  $label"; tail -15 /tmp/check_fast_step.$$; fail=1; fi
  rm -f /tmp/check_fast_step.$$
}

# godot_scene <label> <scene-or-script args...>: runs Godot in game/, needs the count line "0 failures"
# (or "failures: 0"), no engine/script error lines, and a zero exit code.
godot_run() {
  local label="$1" pattern="$2"; shift 2
  local t0=$SECONDS out rc
  out=$(cd game && timeout 600 "$G" --headless "$@" 2>&1); rc=$?
  local bad
  bad=$(echo "$out" | grep -E "SCRIPT ERROR|Parse Error|ERROR:|FAIL:|FAIL " | grep -v "leaked\|still in use")
  local count
  count=$(echo "$out" | grep -E "$pattern" | tail -1)
  if [ $rc -eq 0 ] && [ -n "$count" ] && [ -z "$bad" ]; then note "PASS  $label: $count ($((SECONDS - t0)) s)"
  else
    note "FAIL  $label (exit $rc): ${count:-no result line}"
    [ -n "$bad" ] && echo "$bad" | head -15
    [ -z "$count" ] && echo "$out" | tail -8
    fail=1
  fi
}

echo "== data and strings"
step "validate_data.py" python3 tools/validate_data.py
step "check_strings.py" bash -c 'python3 tools/check_strings.py | tee /dev/stderr | grep -q "^strings OK"'
step "pytest tools" python3 -m pytest -q tools

echo "== import"
(cd game && timeout 600 "$G" --headless --import >/dev/null 2>&1) || { note "FAIL  godot --import"; fail=1; }

echo "== logic tests"
godot_run "run_tests.gd" "^checks: [0-9]+, failures: 0$" --script res://tests/run_tests.gd

echo "== screen tests"
godot_run "ui_smoke" " 0 failures" res://tests/ui_smoke.tscn
for f in game/tests/check_*.tscn; do
  [ -e "$f" ] || continue
  n=$(basename "$f" .tscn)
  case "$n" in check_touch_*) continue ;; esac     # touch scenes run below, with touch emulation
  godot_run "$n" " 0 failures" "res://tests/$n.tscn"
done

echo "== touch scenes (override.cfg: emulate touch from mouse)"
trap 'rm -f game/override.cfg' EXIT
printf '[input_devices]\n\npointing/emulate_touch_from_mouse=true\n' > game/override.cfg
godot_run "ui_touch" " 0 failures" res://tests/ui_touch.tscn
for f in game/tests/check_touch_*.tscn; do
  [ -e "$f" ] || continue
  n=$(basename "$f" .tscn)
  godot_run "$n" " 0 failures" "res://tests/$n.tscn"
done
rm -f game/override.cfg

echo "== golden vectors"
got=$(cd game/tests/golden && LC_ALL=C sha256sum $(ls | LC_ALL=C sort) | sha256sum | cut -d' ' -f1)
if [ "$got" = "$GOLDEN_SHA256" ]; then note "PASS  golden vectors unchanged ($got)"
else note "FAIL  golden vectors changed: $got, recorded $GOLDEN_SHA256"; (cd game/tests/golden && LC_ALL=C sha256sum $(ls | LC_ALL=C sort)); fail=1; fi

echo
echo "== summary"
printf '%s\n' "${results[@]}"
[ $fail -eq 0 ] && echo "check_fast: ALL GREEN" || echo "check_fast: FAILED"
exit $fail

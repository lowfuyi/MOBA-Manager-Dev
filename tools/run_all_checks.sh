#!/usr/bin/env bash
# Run every check. Usage: tools/run_all_checks.sh [path-to-godot-binary]
# Godot is optional; without it the GDScript tests are skipped and reported as skipped.
set -u
cd "$(dirname "$0")/.."
fail=0
python3 tools/validate_data.py || fail=1
python3 tools/validate_arena_map.py || fail=1
python3 tools/validate_arena_map.py --selftest >/dev/null || fail=1
python3 tools/check_strings.py || fail=1
python3 -m pytest -q tools || fail=1
python3 -I tools/calibrate.py 40000 --check || fail=1
G="${1:-${GODOT:-}}"
if [ -n "$G" ] && [ -x "$G" ]; then
  (cd game && "$G" --headless --import >/dev/null 2>&1; timeout 600 "$G" --headless --script res://tests/run_tests.gd) || fail=1
  # UI smoke: the real Main scene driven through a whole season; engine/script errors in the log count as failures
  out=$(cd game && timeout 600 "$G" --headless res://tests/ui_smoke.tscn 2>&1); echo "$out" | tail -3
  if echo "$out" | grep -E "SCRIPT ERROR|Parse Error|ERROR:|FAIL:" | grep -v "leaked\|still in use" ; then fail=1; fi
  echo "$out" | grep -q " 0 failures" || fail=1
  # Area scenes: every tests/check_*.tscn (headless; touch ones run below). Each ends " N checks, 0 failures".
  for f in game/tests/check_*.tscn; do
    [ -e "$f" ] || continue
    n=$(basename "$f" .tscn)
    case "$n" in check_touch_*) continue ;; esac
    out=$(cd game && timeout 600 "$G" --headless "res://tests/$n.tscn" 2>&1); echo "$n: $(echo "$out" | grep -E " [0-9]+ checks, " | tail -1)"
    if echo "$out" | grep -E "SCRIPT ERROR|Parse Error|ERROR:|FAIL:" | grep -v "leaked\|still in use" ; then fail=1; fi
    echo "$out" | grep -q " 0 failures" || fail=1
  done
  # Soak, short version: random manager behaviour over a few full seasons, invariants after every season
  out=$(cd game && timeout 600 "$G" --headless --script res://tests/soak.gd -- 3 2 2>&1); echo "$out" | grep -E "^soak:|BROKEN"
  echo "$out" | grep -q " 0 failures" || fail=1
  # Touch behaviour: swipes must scroll (also from buttons), taps must tap, Android back must navigate.
  # A scroll container only takes touch drags when a touchscreen exists, so the desktop run emulates one.
  printf '[input_devices]\n\npointing/emulate_touch_from_mouse=true\n' > game/override.cfg
  out=$(cd game && timeout 600 "$G" --headless res://tests/ui_touch.tscn 2>&1); rm -f game/override.cfg
  echo "$out" | grep -E "FAIL|failures"
  echo "$out" | grep -q " 0 failures" || fail=1
  # Touch area scenes: every tests/check_touch_*.tscn, same touch emulation
  printf '[input_devices]\n\npointing/emulate_touch_from_mouse=true\n' > game/override.cfg
  for f in game/tests/check_touch_*.tscn; do
    [ -e "$f" ] || continue
    n=$(basename "$f" .tscn)
    out=$(cd game && timeout 600 "$G" --headless "res://tests/$n.tscn" 2>&1)
    echo "$n: $(echo "$out" | grep -E " [0-9]+ checks, " | tail -1)"
    echo "$out" | grep -q " 0 failures" || fail=1
  done
  rm -f game/override.cfg
  # Golden vectors: the value is recorded in tools/check_fast.sh (one place). The simulation must not change in 0.7.
  want=$(grep '^GOLDEN_SHA256=' tools/check_fast.sh | cut -d= -f2)
  got=$(cd game/tests/golden && LC_ALL=C sha256sum $(ls | LC_ALL=C sort) | sha256sum | cut -d' ' -f1)
  if [ "$got" = "$want" ]; then echo "golden vectors unchanged"; else echo "FAIL: golden vectors changed ($got, recorded $want)"; fail=1; fi
  # Perf gate (PERF-BUDGET.md 3.1a): needs a renderer, so Xvfb with software OpenGL. Visits the 49 tour states and judges
  # them against game/tests/perf_allowances.json (legacy rows are limits, no row = hard limits, redesigned = target or
  # waiver). Prints NO ROW and "tighten to N" notes. Any PERF FAIL line, a missing summary line or a nonzero count fails.
  if command -v xvfb-run >/dev/null 2>&1; then
    out=$(cd game && timeout 600 xvfb-run -a -s "-screen 0 720x1280x24" "$G" --rendering-driver opengl3 res://tests/perf_baseline.tscn 2>&1)
    echo "$out" | grep -E "^PERF\||^PERF NOTE|^PERF TABLE|^perf:"
    echo "$out" | grep -q "PERF FAIL" && fail=1
    echo "$out" | grep -qE "^perf: [0-9]+ states, .*, 0 failures$" || fail=1
  else
    echo "SKIPPED: perf gate (no xvfb-run)"
  fi
else
  echo "SKIPPED: GDScript tests (no Godot binary given)"
fi
exit $fail

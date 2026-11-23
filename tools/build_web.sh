#!/usr/bin/env bash
# Web playtest build (0.11.1 web; Founder request 2026-11-22). Exports game/ with the "Web" preset (single-threaded, GL
# Compatibility, PWA) into build/web/ (git-ignored), with a build id testers can quote and the hosting files.
#   GODOT=/path/to/godot [FEEDBACK_URL=https://...] [GAME_DIR=game] tools/build_web.sh
# game/build_info.json exists only during the export (never committed). Nothing here deploys; see docs/WEB-PLAYTEST.md.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
G=${GODOT:?set GODOT to the Godot 4.3 binary}
GD=${GAME_DIR:-$ROOT/game}
OUT=${OUT_DIR:-$ROOT/build/web}
ver=$(grep -oP 'VERSION_LABEL := "\K[^"]+' "$GD/src/core/app.gd")
sha=$(git -C "$ROOT" rev-parse --short HEAD)
if [ -n "$(git -C "$ROOT" status --porcelain -- game | grep -v build_info.json || true)" ]; then sha="$sha+"; fi
BUILD="${ver// /-}-web-$sha-$(date -u +%Y%m%d-%H%M)"
trap 'rm -f "$GD/build_info.json"' EXIT
BUILD="$BUILD" FEEDBACK_URL="${FEEDBACK_URL:-}" python3 -c '
import json, os, sys, time
json.dump({"build": os.environ["BUILD"], "feedback_url": os.environ["FEEDBACK_URL"],
           "built": time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime())}, open(sys.argv[1], "w"))' "$GD/build_info.json"
rm -rf "$OUT"
mkdir -p "$OUT"
(cd "$GD" && timeout 600 "$G" --headless --import >/dev/null 2>&1 || true)
(cd "$GD" && timeout 900 "$G" --headless --export-release "Web" "$OUT/index.html" 2>&1 | grep -E "ERROR|WARNING" | grep -v "No project icon" || true)
[ -s "$OUT/index.pck" ] && [ -s "$OUT/index.wasm" ] || { echo "build_web: export failed"; exit 1; }
sed -i "s/__GL_BUILD__/$BUILD/" "$OUT/index.html"
cp "$ROOT/tools/web/vercel.json" "$OUT/vercel.json"   # Vercel: headers only, no build step or functions
cp "$ROOT/tools/web/_headers" "$OUT/_headers"         # the same headers for Netlify and Cloudflare Pages
printf 'User-agent: *\nDisallow: /\n' > "$OUT/robots.txt"
# iPhone launch images for Home Screen use (0.12 Q2): generated into the build only, never committed or shipped in the APK
(cd "$GD" && timeout 300 "$G" --headless --script "$ROOT/tools/gen_pwa_splash.gd" -- "$OUT" 2>&1 | grep -c "^splash" | xargs -I{} echo "  {} launch images") || true
echo "$BUILD" > "$OUT/build.txt"
echo "build_web: $BUILD"
( cd "$OUT" && for f in index.html index.js index.wasm index.pck index.audio.worklet.js index.service.worker.js index.manifest.json; do
    [ -e "$f" ] && printf '  %-28s %9d bytes  gzip %9d\n' "$f" "$(stat -c %s "$f")" "$(gzip -9c "$f" | wc -c)"; done )

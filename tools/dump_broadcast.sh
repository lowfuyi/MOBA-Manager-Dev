#!/bin/bash
# Print a whole game's broadcast (Match Day M4). Usage: GODOT=... tools/dump_broadcast.sh [calm|thriller|<index>] [games]
# Display only: it builds games like tests/check_cast and prints ArenaCast.transcript(). Not part of the fast gate.
cd "$(dirname "$0")/../game" || exit 1
DB_PICK="${1:-thriller}" DB_GAMES="${2:-12}" timeout 600 "${GODOT:?set GODOT}" --headless res://tests/dump_broadcast.tscn 2>/dev/null | sed -n '/^BROADCAST/,$p'

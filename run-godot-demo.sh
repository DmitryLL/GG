#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/bvd/codex/GG"
GODOT_BIN="/home/bvd/.local/opt/godot-4.3/Godot_v4.3-stable_linux.x86_64"
LIB_DIR="/home/bvd/.local/opt/godot-libs/usr/lib/x86_64-linux-gnu"

mkdir -p "$LIB_DIR"
if [[ -f "$LIB_DIR/libXcursor.so.1.0.2" && ! -e "$LIB_DIR/libXcursor.so.1" ]]; then
	ln -sf "$LIB_DIR/libXcursor.so.1.0.2" "$LIB_DIR/libXcursor.so.1"
fi
if [[ -f "$LIB_DIR/libwayland-cursor.so.0.0.0" && ! -e "$LIB_DIR/libwayland-cursor.so.0" ]]; then
	ln -sf "$LIB_DIR/libwayland-cursor.so.0.0.0" "$LIB_DIR/libwayland-cursor.so.0"
fi

export LD_LIBRARY_PATH="$LIB_DIR:${LD_LIBRARY_PATH:-}"

exec "$GODOT_BIN" --path "$ROOT/godot"

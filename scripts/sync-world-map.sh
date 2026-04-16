#!/usr/bin/env bash
# После правки data/maps/world.tmj в Tiled — запусти этот скрипт,
# чтобы синхронизировать копию клиента и пересобрать server data.
set -euo pipefail
cd "$(dirname "$0")/.."

cp data/maps/world.tmj godot/assets/world.tmj
echo "✓ godot/assets/world.tmj синхронизирован"

cd nakama-server
node scripts/gen-data.js
echo "✓ nakama-server/src/data.gen.ts пересобран"

echo
echo "Дальше:"
echo "  git add data/maps/world.tmj godot/assets/world.tmj nakama-server/src/data.gen.ts"
echo "  git commit -m 'карта: <что изменил>'"
echo "  git push"

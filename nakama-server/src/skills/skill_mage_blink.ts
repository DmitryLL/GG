// Mage skill 4: Блинк — телепорт на 5 тайлов.
// Моды:
//   "cd_reduce"    (1п) — КД × 0.7.
//   "blink_explode"(2п) — в точке прибытия AoE 120% от baseDmg, до 5 целей.
registerMageSkill(4, {
    requiresBow: false,
    cooldownMs: 8000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;
        let dx = Number(body.dx) || 0;
        let dy = Number(body.dy) || 0;
        const len = Math.sqrt(dx * dx + dy * dy);
        if (len < 0.01) { dx = 0; dy = 1; }
        else { dx /= len; dy /= len; }
        const tiles = currentTiles(state);
        const maxDist = 5 * TILE_SIZE;  // 5 тайлов
        const step = 6;
        let reach = 0;
        for (let s = step; s <= maxDist; s += step) {
            const tx = player.pos.x + dx * s;
            const ty = player.pos.y + dy * s;
            if (!isWalkableAt(tiles, tx, ty)) break;
            reach = s;
        }
        const nx = player.pos.x + dx * reach;
        const ny = player.pos.y + dy * reach;
        player.pos.x = Math.max(TILE_SIZE, Math.min(MAP_WIDTH - TILE_SIZE, nx));
        player.pos.y = Math.max(TILE_SIZE, Math.min(MAP_HEIGHT - TILE_SIZE, ny));
        player.dirtyPos = true;
        player.moveTarget = null;
        player.movePath = [];
        player.invulnUntil = t + 300;

        const mod = player.mageMods ? player.mageMods["4"] : "";
        let cd = 8000;
        if (mod === "cd_reduce") cd = Math.floor(cd * 0.7);

        dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
            kind: "dodge", sid: player.sessionId,
            fx: player.pos.x, fy: player.pos.y,
        }));

        if (mod === "blink_explode") {
            const explodeDmg = Math.max(1, Math.floor(baseDmg * 1.2));
            const R = 48;
            let hit = 0;
            for (const mk of Object.keys(state.mobs)) {
                if (hit >= 5) break;
                const m = state.mobs[mk];
                if (m.state !== "alive") continue;
                if (Math.abs(m.pos.x - player.pos.x) > R || Math.abs(m.pos.y - player.pos.y) > R) continue;
                m.hp -= explodeDmg;
                m.dirty = true;
                dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({
                    mobId: m.id, dmg: explodeDmg, ghost: true,
                }));
                if (m.hp <= 0) killMob(m, player, t);
                hit++;
            }
            dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
                kind: "blink_explode", x: player.pos.x, y: player.pos.y, r: R,
            }));
        }
        player.skillCd[4] = t + cd;
    },
});

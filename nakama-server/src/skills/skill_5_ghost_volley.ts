// Скилл 5: Призрачный залп — 5 стрел в конусе.
registerSkill(5, {
    requiresBow: true,
    cooldownMs: 15000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;
        const targetX = Number(body.x);
        const targetY = Number(body.y);
        const aimX = isFinite(targetX) ? targetX : player.pos.x + 100;
        const aimY = isFinite(targetY) ? targetY : player.pos.y;
        const baseAng = Math.atan2(aimY - player.pos.y, aimX - player.pos.x);
        const angles = [-0.35, -0.17, 0, 0.17, 0.35];
        const hit = new Set<string>();
        for (const da of angles) {
            const ang = baseAng + da;
            const tx = player.pos.x + Math.cos(ang) * PLAYER_ATTACK_RANGE;
            const ty = player.pos.y + Math.sin(ang) * PLAYER_ATTACK_RANGE;
            dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                fx: player.pos.x, fy: player.pos.y, tx: tx, ty: ty,
                ghost: true,
            }));
            const vx = tx - player.pos.x, vy = ty - player.pos.y;
            const v2 = vx * vx + vy * vy;
            for (const mk of Object.keys(state.mobs)) {
                const m = state.mobs[mk];
                if (m.state !== "alive" || hit.has(m.id)) continue;
                const wx = m.pos.x - player.pos.x, wy = m.pos.y - player.pos.y;
                const proj = (wx * vx + wy * vy) / v2;
                if (proj < 0 || proj > 1) continue;
                const px = player.pos.x + proj * vx, py = player.pos.y + proj * vy;
                const dd = Math.sqrt((m.pos.x - px) ** 2 + (m.pos.y - py) ** 2);
                if (dd < 24) {
                    const dmg = Math.floor(baseDmg * 0.8);
                    m.hp -= dmg;
                    m.dirty = true;
                    hit.add(m.id);
                    dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({
                        mobId: m.id, dmg: dmg, ghost: true,
                    }));
                    if (m.hp <= 0) killMob(m, player, t);
                }
            }
            // PvP: попадаем в чужих игроков в конусе
            for (const sk of Object.keys(state.players)) {
                const tp = state.players[sk];
                if (tp.sessionId === player.sessionId || tp.hp <= 0 || hit.has(tp.sessionId)) continue;
                if (t < tp.invulnUntil) continue;
                const wx = tp.pos.x - player.pos.x, wy = tp.pos.y - player.pos.y;
                const proj = (wx * vx + wy * vy) / v2;
                if (proj < 0 || proj > 1) continue;
                const px = player.pos.x + proj * vx, py = player.pos.y + proj * vy;
                const dd = Math.sqrt((tp.pos.x - px) ** 2 + (tp.pos.y - py) ** 2);
                if (dd < 24) {
                    const dmg = Math.floor(baseDmg * 0.8);
                    tp.hp -= dmg;
                    if (tp.hp < 0) tp.hp = 0;
                    markMe(tp);
                    hit.add(tp.sessionId);
                    dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({
                        sessionId: tp.sessionId, by: player.sessionId, dmg: dmg, ghost: true,
                    }));
                    if (tp.hp <= 0) {
                        tp.pos.x = WORLD.playerSpawn.x; tp.pos.y = WORLD.playerSpawn.y;
                        tp.hp = tp.hpMax; tp.lastTouchedByMob = {};
                        tp.dirtyPos = true; markMe(tp);
                    }
                }
            }
        }
        player.skillCd[5] = t + 15000;
    },
});

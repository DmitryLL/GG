// Скилл 3: Отскок — телепорт от цели + 0.5s неуязвимости + 3s atk speed x2.
registerSkill(3, {
    requiresBow: false,
    cooldownMs: 8000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher } = ctx;
        const target = body.mobId ? state.mobs[String(body.mobId)] : null;
        let dx = 0, dy = 1;
        if (target) {
            const vx = player.pos.x - target.pos.x;
            const vy = player.pos.y - target.pos.y;
            const len = Math.sqrt(vx * vx + vy * vy) || 1;
            dx = vx / len; dy = vy / len;
        }
        player.pos.x = Math.max(TILE_SIZE, Math.min(MAP_WIDTH - TILE_SIZE, player.pos.x + dx * 80));
        player.pos.y = Math.max(TILE_SIZE, Math.min(MAP_HEIGHT - TILE_SIZE, player.pos.y + dy * 80));
        player.dirtyPos = true;
        player.invulnUntil = t + 500;
        player.atkSpeedBoostUntil = t + 3000;
        dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
            kind: "dodge", sid: player.sessionId,
            fx: player.pos.x, fy: player.pos.y,
        }));
        player.skillCd[3] = t + 8000;
    },
});

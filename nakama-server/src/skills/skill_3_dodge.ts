// Скилл 3: Отскок — телепорт от цели + 0.5s неуязвимости + 3s atk speed x2.
registerSkill(3, {
    requiresBow: false,
    cooldownMs: 8000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, dispatcher } = ctx;
        // Направление: сначала dx/dy от клиента (взгляд), иначе вниз
        let dx = Number(body.dx) || 0;
        let dy = Number(body.dy) || 0;
        const len = Math.sqrt(dx * dx + dy * dy);
        if (len < 0.01) { dx = 0; dy = 1; }
        else { dx /= len; dy /= len; }
        // Сохраняем конечную цель ходьбы ДО телепорта: если игрок шёл куда-то,
        // должен продолжить идти туда же после Dodge, а не тянуться обратно
        // к промежуточному moveTarget, оказавшемуся позади.
        const finalDest: Vec2 | null = (player.movePath && player.movePath.length > 0)
            ? player.movePath[player.movePath.length - 1]
            : player.moveTarget;
        player.pos.x = Math.max(TILE_SIZE, Math.min(MAP_WIDTH - TILE_SIZE, player.pos.x + dx * 80));
        player.pos.y = Math.max(TILE_SIZE, Math.min(MAP_HEIGHT - TILE_SIZE, player.pos.y + dy * 80));
        player.dirtyPos = true;
        // Сбрасываем промежуточные waypoints и ведём игрока напрямую к финалу.
        player.movePath = [];
        if (finalDest) {
            const ddx = finalDest.x - player.pos.x;
            const ddy = finalDest.y - player.pos.y;
            // Если уже дошли (≤ 8px от финала) — просто стоим.
            player.moveTarget = (ddx * ddx + ddy * ddy < 64) ? null : { x: finalDest.x, y: finalDest.y };
        } else {
            player.moveTarget = null;
        }
        player.invulnUntil = t + 500;
        player.atkSpeedBoostUntil = t + 3000;
        dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
            kind: "dodge", sid: player.sessionId,
            fx: player.pos.x, fy: player.pos.y,
        }));
        player.skillCd[3] = t + 8000;
    },
});
